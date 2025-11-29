"""
Migration Script 06: Sync Student Activities from Knack to Supabase
====================================================================

This script migrates all student activity assignments and completions from Knack Object_6 to Supabase.

Knack Fields (Object_6):
- field_1683: Prescribed Activities (connections to Object_44)
- field_1380: Finished Activities (CSV of activity IDs)
- field_3580: Student-Added Activities
- field_3581: Staff-Added Activities  
- field_2335: Completed One Activity (boolean)
- field_1810: Activity Notifications On/Off (boolean)

Supabase Tables:
- student_activities: Assigned/prescribed activities
- activity_responses: Completion records
- vespa_students: Student preferences
"""

import os
import sys
from pathlib import Path
from supabase import create_client, Client
from dotenv import load_dotenv
import requests
import json
from datetime import datetime

# Load environment variables from DASHBOARD/.env
env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

# Supabase connection
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    print("❌ Error: SUPABASE_URL or SUPABASE_SERVICE_KEY not found in .env file")
    print(f"   Looking for .env at: {env_path}")
    sys.exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

# Knack API credentials
KNACK_APP_ID = os.getenv('KNACK_APP_ID')
KNACK_API_KEY = os.getenv('KNACK_API_KEY')

if not KNACK_APP_ID or not KNACK_API_KEY:
    print("❌ Error: KNACK_APP_ID or KNACK_API_KEY not found in .env file")
    sys.exit(1)

KNACK_API_BASE = 'https://api.knack.com/v1'

# Statistics
stats = {
    'students_processed': 0,
    'students_skipped': 0,
    'prescribed_activities_synced': 0,
    'finished_activities_synced': 0,
    'student_added_synced': 0,
    'staff_added_synced': 0,
    'errors': []
}


def fetch_knack_students(page=1, per_page=100):
    """Fetch students from Knack Object_6"""
    url = f"{KNACK_API_BASE}/objects/object_6/records"
    
    params = {
        'rows_per_page': per_page,
        'page': page
    }
    
    headers = {
        'X-Knack-Application-Id': KNACK_APP_ID,
        'X-Knack-REST-API-Key': KNACK_API_KEY
    }
    
    response = requests.get(url, params=params, headers=headers)
    
    if response.status_code != 200:
        print(f"❌ Failed to fetch students: {response.status_code} - {response.text}")
        return None
    
    data = response.json()
    return data


def get_or_create_vespa_student(email):
    """Get or create student record in vespa_students table"""
    try:
        # Check if exists
        result = supabase.table('vespa_students').select('id').eq('email', email).execute()
        
        if result.data and len(result.data) > 0:
            return result.data[0]['id']
        
        # Create new record
        new_student = {
            'email': email,
            'auth_provider': 'knack',
            'status': 'active',
            'is_active': True
        }
        
        result = supabase.table('vespa_students').insert(new_student).execute()
        
        if result.data and len(result.data) > 0:
            print(f"   ✅ Created vespa_student for {email}")
            return result.data[0]['id']
        
        return None
        
    except Exception as e:
        print(f"   ⚠️ Error creating vespa_student for {email}: {str(e)}")
        return None


def get_activity_id_by_knack_id(knack_id):
    """Get Supabase activity UUID from Knack record ID"""
    try:
        result = supabase.table('activities').select('id').eq('knack_id', knack_id).execute()
        
        if result.data and len(result.data) > 0:
            return result.data[0]['id']
        
        return None
    except Exception as e:
        print(f"   ⚠️ Error fetching activity by knack_id {knack_id}: {str(e)}")
        return None


def get_activity_id_by_name(activity_name):
    """Get Supabase activity UUID from activity name"""
    try:
        result = supabase.table('activities').select('id').eq('name', activity_name).execute()
        
        if result.data and len(result.data) > 0:
            return result.data[0]['id']
        
        return None
    except Exception as e:
        print(f"   ⚠️ Error fetching activity by name {activity_name}: {str(e)}")
        return None


def sync_student_activities(student_record):
    """Sync a single student's activity data from Knack to Supabase"""
    try:
        # Extract email
        email = student_record.get('field_91') or student_record.get('field_91_raw')
        
        # Handle email formatting (sometimes wrapped in dict)
        if isinstance(email, dict):
            email = email.get('email')
        
        # Handle HTML anchor format
        if isinstance(email, str) and '<a href="mailto:' in email:
            import re
            email_match = re.search(r'mailto:([^"]+)', email)
            if email_match:
                email = email_match.group(1)
        
        if not email or not isinstance(email, str) or '@' not in email:
            stats['students_skipped'] += 1
            return False
        
        print(f"\n📧 Processing: {email}")
        
        # Get or create vespa_student
        vespa_student_id = get_or_create_vespa_student(email)
        if not vespa_student_id:
            print(f"   ❌ Failed to get/create vespa_student")
            stats['students_skipped'] += 1
            return False
        
        # Get current cycle (default to 1)
        current_cycle = 1
        
        # ============================================
        # 1. PRESCRIBED ACTIVITIES (field_1683)
        # ============================================
        # NOTE: field_1683 is a CONNECTION field that returns HTML with activity data
        # Format: <span class="KNACK_ID" data-kn="connection-value">Activity Name</span>
        prescribed_field = student_record.get('field_1683') or student_record.get('field_1683_raw') or []
        prescribed_activities = []
        
        # Parse prescribed activities
        if isinstance(prescribed_field, str) and prescribed_field.strip():
            # HTML format - extract IDs from class attributes and names from text
            import re
            
            # Find all spans with class containing 24-char Knack IDs and activity names
            pattern = r'<span class="([a-f0-9]{24})"[^>]*>([^<]+)</span>'
            matches = re.findall(pattern, prescribed_field)
            
            for knack_id, activity_name in matches:
                prescribed_activities.append({
                    'name': activity_name.strip(),
                    'knack_id': knack_id.strip()
                })
        
        elif isinstance(prescribed_field, list):
            for item in prescribed_field:
                if isinstance(item, dict):
                    # Could have 'identifier' (name), 'id' (knack_id), or both
                    activity_name = item.get('identifier') or item.get('name')
                    activity_id = item.get('id')
                    prescribed_activities.append({'name': activity_name, 'knack_id': activity_id})
                elif isinstance(item, str):
                    # Could be a name or an ID
                    if len(item) == 24:  # Looks like Knack ID
                        prescribed_activities.append({'name': None, 'knack_id': item})
                    else:  # Probably a name
                        prescribed_activities.append({'name': item, 'knack_id': None})
        
        if prescribed_activities:
            print(f"   📋 Prescribed Activities: {len(prescribed_activities)}")
            
            for activity_info in prescribed_activities:
                activity_name = activity_info['name']
                knack_activity_id = activity_info['knack_id']
                
                # Try to get Supabase UUID - prioritize name lookup (more reliable for field_1683)
                activity_uuid = None
                
                if activity_name:
                    activity_uuid = get_activity_id_by_name(activity_name)
                
                if not activity_uuid and knack_activity_id:
                    activity_uuid = get_activity_id_by_knack_id(knack_activity_id)
                
                if not activity_uuid:
                    print(f"      ⚠️ Activity not found: name={activity_name}, id={knack_activity_id}")
                    continue
                
                # Insert into student_activities
                try:
                    assignment = {
                        'student_email': email,
                        'activity_id': activity_uuid,
                        'cycle_number': current_cycle,
                        'assigned_by': 'auto',
                        'assigned_reason': 'Migrated from Knack field_1683',
                        'status': 'assigned',
                        'assigned_at': datetime.utcnow().isoformat()
                    }
                    
                    supabase.table('student_activities').upsert(
                        assignment,
                        on_conflict='student_email,activity_id,cycle_number'
                    ).execute()
                    
                    stats['prescribed_activities_synced'] += 1
                    
                except Exception as e:
                    print(f"      ⚠️ Error syncing prescribed activity {knack_activity_id}: {str(e)}")
        
        # ============================================
        # 2. FINISHED ACTIVITIES (field_1380)
        # ============================================
        finished_field = student_record.get('field_1380') or student_record.get('field_1380_raw') or ''
        finished_activity_ids = []
        
        if isinstance(finished_field, str) and finished_field.strip():
            finished_activity_ids = [aid.strip() for aid in finished_field.split(',') if aid.strip()]
        
        if finished_activity_ids:
            print(f"   ✅ Finished Activities: {len(finished_activity_ids)}")
            
            for knack_activity_id in finished_activity_ids:
                # Get Supabase activity UUID
                activity_uuid = get_activity_id_by_knack_id(knack_activity_id)
                
                if not activity_uuid:
                    print(f"      ⚠️ Finished activity not found in Supabase: {knack_activity_id}")
                    continue
                
                # Check if response record already exists (from historical migration)
                existing = supabase.table('activity_responses').select('id, status').eq('student_email', email).eq('activity_id', activity_uuid).eq('cycle_number', current_cycle).execute()
                
                if existing.data and len(existing.data) > 0:
                    # Update status to completed
                    supabase.table('activity_responses').update({
                        'status': 'completed',
                        'completed_at': datetime.utcnow().isoformat()
                    }).eq('id', existing.data[0]['id']).execute()
                else:
                    # Create completed record
                    try:
                        response_record = {
                            'student_email': email,
                            'activity_id': activity_uuid,
                            'cycle_number': current_cycle,
                            'academic_year': '2025/2026',
                            'status': 'completed',
                            'responses': {},
                            'selected_via': 'migrated',
                            'started_at': datetime.utcnow().isoformat(),
                            'completed_at': datetime.utcnow().isoformat()
                        }
                        
                        supabase.table('activity_responses').insert(response_record).execute()
                    except Exception as e:
                        print(f"      ⚠️ Error creating response record: {str(e)}")
                
                # Update student_activities to completed
                try:
                    supabase.table('student_activities').update({
                        'status': 'completed'
                    }).eq('student_email', email).eq('activity_id', activity_uuid).eq('cycle_number', current_cycle).execute()
                    
                    stats['finished_activities_synced'] += 1
                    
                except Exception as e:
                    print(f"      ⚠️ Error updating student_activities: {str(e)}")
        
        # ============================================
        # 3. STUDENT-ADDED ACTIVITIES (field_3580)
        # ============================================
        student_added_field = student_record.get('field_3580') or student_record.get('field_3580_raw') or ''
        student_added_ids = []
        
        if isinstance(student_added_field, str) and student_added_field.strip():
            student_added_ids = [aid.strip() for aid in student_added_field.split(',') if aid.strip()]
        
        if student_added_ids:
            print(f"   👤 Student-Added Activities: {len(student_added_ids)}")
            
            for knack_activity_id in student_added_ids:
                activity_uuid = get_activity_id_by_knack_id(knack_activity_id)
                
                if not activity_uuid:
                    continue
                
                try:
                    assignment = {
                        'student_email': email,
                        'activity_id': activity_uuid,
                        'cycle_number': current_cycle,
                        'assigned_by': 'student',
                        'assigned_reason': 'Student self-selected (migrated from field_3580)',
                        'status': 'assigned',
                        'assigned_at': datetime.utcnow().isoformat()
                    }
                    
                    supabase.table('student_activities').upsert(
                        assignment,
                        on_conflict='student_email,activity_id,cycle_number'
                    ).execute()
                    
                    stats['student_added_synced'] += 1
                    
                except Exception as e:
                    print(f"      ⚠️ Error: {str(e)}")
        
        # ============================================
        # 4. STAFF-ADDED ACTIVITIES (field_3581)
        # ============================================
        staff_added_field = student_record.get('field_3581') or student_record.get('field_3581_raw') or ''
        staff_added_ids = []
        
        if isinstance(staff_added_field, str) and staff_added_field.strip():
            staff_added_ids = [aid.strip() for aid in staff_added_field.split(',') if aid.strip()]
        
        if staff_added_ids:
            print(f"   👨‍🏫 Staff-Added Activities: {len(staff_added_ids)}")
            
            for knack_activity_id in staff_added_ids:
                activity_uuid = get_activity_id_by_knack_id(knack_activity_id)
                
                if not activity_uuid:
                    continue
                
                try:
                    assignment = {
                        'student_email': email,
                        'activity_id': activity_uuid,
                        'cycle_number': current_cycle,
                        'assigned_by': 'staff',
                        'assigned_reason': 'Staff assigned (migrated from field_3581)',
                        'status': 'assigned',
                        'assigned_at': datetime.utcnow().isoformat()
                    }
                    
                    supabase.table('student_activities').upsert(
                        assignment,
                        on_conflict='student_email,activity_id,cycle_number'
                    ).execute()
                    
                    stats['staff_added_synced'] += 1
                    
                except Exception as e:
                    print(f"      ⚠️ Error: {str(e)}")
        
        # ============================================
        # 5. PREFERENCES (field_2335, field_1810)
        # ============================================
        completed_one = student_record.get('field_2335') or student_record.get('field_2335_raw')
        notifications_on = student_record.get('field_1810') or student_record.get('field_1810_raw')
        
        # Convert to booleans
        completed_one_bool = completed_one in [True, 'true', 'True', 'Yes']
        notifications_on_bool = notifications_on not in [False, 'false', 'False', 'No']  # Default to True
        
        # Update vespa_students preferences
        try:
            preferences = {
                'completed_first_activity': completed_one_bool,
                'notifications_enabled': notifications_on_bool,
                'migrated_from_knack': True,
                'migration_date': datetime.utcnow().isoformat()
            }
            
            supabase.table('vespa_students').update({
                'preferences': preferences
            }).eq('email', email).execute()
            
            print(f"   ⚙️ Preferences: completed_first={completed_one_bool}, notifications={notifications_on_bool}")
            
        except Exception as e:
            print(f"      ⚠️ Error updating preferences: {str(e)}")
        
        # ============================================
        # 6. UPDATE TOTALS IN vespa_students
        # ============================================
        try:
            # Count completed activities
            completed_count = len(finished_activity_ids) if finished_activity_ids else 0
            
            # Calculate total points (10 for Level 2, 15 for Level 3)
            # For simplicity, assume 10 points per activity (can be refined later)
            total_points = completed_count * 10
            
            supabase.table('vespa_students').update({
                'total_activities_completed': completed_count,
                'total_points': total_points,
                'last_synced_from_knack': datetime.utcnow().isoformat()
            }).eq('email', email).execute()
            
        except Exception as e:
            print(f"      ⚠️ Error updating totals: {str(e)}")
        
        stats['students_processed'] += 1
        return True
        
    except Exception as e:
        error_msg = f"Error processing student {email}: {str(e)}"
        print(f"   ❌ {error_msg}")
        stats['errors'].append(error_msg)
        stats['students_skipped'] += 1
        return False


def main():
    """Main migration function"""
    print("=" * 80)
    print("VESPA Activities Migration Step 06: Student Activities from Knack")
    print("=" * 80)
    print()
    print(f"🔗 Supabase URL: {SUPABASE_URL}")
    print(f"🔗 Knack App ID: {KNACK_APP_ID}")
    print()
    print("This script will:")
    print("  1. Fetch all students from Knack Object_6")
    print("  2. Sync prescribed activities (field_1683) → student_activities")
    print("  3. Sync finished activities (field_1380) → activity_responses + student_activities")
    print("  4. Sync student-added (field_3580) → student_activities")
    print("  5. Sync staff-added (field_3581) → student_activities")
    print("  6. Sync preferences (field_2335, field_1810) → vespa_students")
    print()
    
    confirm = input("⚠️  Continue with migration? (yes/no): ")
    if confirm.lower() not in ['yes', 'y']:
        print("❌ Migration cancelled")
        return
    
    print("\n🚀 Starting migration...\n")
    
    # Fetch all students from Knack
    page = 1
    total_records = 0
    
    while True:
        print(f"📄 Fetching page {page}...")
        
        data = fetch_knack_students(page=page, per_page=100)
        
        if not data:
            print("❌ Failed to fetch students")
            break
        
        records = data.get('records', [])
        total_records += len(records)
        
        print(f"   Found {len(records)} students on page {page}")
        
        if not records:
            break
        
        # Process each student
        for record in records:
            sync_student_activities(record)
        
        # Check if there are more pages
        current_page = data.get('current_page', page)
        total_pages = data.get('total_pages', 1)
        
        if current_page >= total_pages:
            break
        
        page += 1
    
    # ============================================
    # SUMMARY
    # ============================================
    print("\n" + "=" * 80)
    print("MIGRATION COMPLETE")
    print("=" * 80)
    print(f"\n📊 Statistics:")
    print(f"   Total Students Fetched: {total_records}")
    print(f"   Students Processed: {stats['students_processed']}")
    print(f"   Students Skipped: {stats['students_skipped']}")
    print(f"   Prescribed Activities Synced: {stats['prescribed_activities_synced']}")
    print(f"   Finished Activities Synced: {stats['finished_activities_synced']}")
    print(f"   Student-Added Activities Synced: {stats['student_added_synced']}")
    print(f"   Staff-Added Activities Synced: {stats['staff_added_synced']}")
    print(f"   Errors: {len(stats['errors'])}")
    
    if stats['errors']:
        print("\n⚠️  Errors encountered:")
        for error in stats['errors'][:10]:  # Show first 10 errors
            print(f"   - {error}")
        if len(stats['errors']) > 10:
            print(f"   ... and {len(stats['errors']) - 10} more")
    
    print("\n✅ Migration Step 06 Complete!")
    print("\n📋 Next Steps:")
    print("   1. Verify data in Supabase:")
    print("      SELECT COUNT(*) FROM student_activities;")
    print("   2. Test the Vue app - students should now see their activities")
    print("   3. Run this script again just before final switchover for latest data")
    print()


if __name__ == "__main__":
    main()

