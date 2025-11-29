"""
Test Script: Sync Single Student Activities from Knack to Supabase
===================================================================

Test the migration logic with one specific student.
"""

import os
import sys
from pathlib import Path
from supabase import create_client, Client
from dotenv import load_dotenv
import requests
from datetime import datetime

# Load environment variables
env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')
KNACK_APP_ID = os.getenv('KNACK_APP_ID')
KNACK_API_KEY = os.getenv('KNACK_API_KEY')

if not all([SUPABASE_URL, SUPABASE_SERVICE_KEY, KNACK_APP_ID, KNACK_API_KEY]):
    print("❌ Error: Missing environment variables")
    sys.exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
KNACK_API_BASE = 'https://api.knack.com/v1'

# Test email
TEST_EMAIL = '354355@nptcgroup.ac.uk'


def get_activity_id_by_knack_id(knack_id):
    """Get Supabase activity UUID from Knack record ID"""
    try:
        result = supabase.table('activities').select('id, name').eq('knack_id', knack_id).execute()
        if result.data and len(result.data) > 0:
            return result.data[0]['id'], result.data[0]['name']
        return None, None
    except Exception as e:
        print(f"   ⚠️ Error: {str(e)}")
        return None, None


def get_activity_id_by_name(activity_name):
    """Get Supabase activity UUID from activity name"""
    try:
        result = supabase.table('activities').select('id').eq('name', activity_name).execute()
        if result.data and len(result.data) > 0:
            return result.data[0]['id']
        return None
    except Exception as e:
        print(f"   ⚠️ Error: {str(e)}")
        return None


def fetch_student_by_email(email):
    """Fetch student from Knack by email - use pagination to get full record"""
    url = f"{KNACK_API_BASE}/objects/object_6/records"
    
    headers = {
        'X-Knack-Application-Id': KNACK_APP_ID,
        'X-Knack-REST-API-Key': KNACK_API_KEY
    }
    
    # Fetch first few pages and find the student
    for page in range(1, 5):
        params = {
            'rows_per_page': 100,
            'page': page
        }
        
        response = requests.get(url, headers=headers, params=params)
        
        if response.status_code != 200:
            print(f"❌ Failed to fetch students: {response.status_code}")
            continue
        
        data = response.json()
        records = data.get('records', [])
        
        # Find student by email
        for record in records:
            student_email = record.get('field_91') or record.get('field_91_raw')
            
            # Handle dict format
            if isinstance(student_email, dict):
                student_email = student_email.get('email')
            
            # Handle HTML anchor format
            if isinstance(student_email, str) and '<a href="mailto:' in student_email:
                import re
                email_match = re.search(r'mailto:([^"]+)', student_email)
                if email_match:
                    student_email = email_match.group(1)
            
            if student_email == email:
                print(f"   Found on page {page}")
                return record
    
    print(f"❌ Student not found in first 400 records")
    return None


def test_sync():
    """Test sync with one student"""
    print("=" * 80)
    print(f"TEST: Syncing Student Activities for {TEST_EMAIL}")
    print("=" * 80)
    print()
    
    # Fetch student from Knack
    print(f"🔍 Fetching student from Knack...")
    student = fetch_student_by_email(TEST_EMAIL)
    
    if not student:
        return
    
    print(f"✅ Found student: {student.get('id')}")
    print()
    
    # DEBUG: Print all fields to see what we're getting
    print("🔍 DEBUG: All field values:")
    for key in sorted(student.keys()):
        if 'field_1' in key or 'field_2' in key or 'field_3' in key:
            value = student.get(key)
            if value:  # Only show non-empty fields
                value_str = str(value)[:100] if len(str(value)) > 100 else str(value)
                print(f"   {key}: {value_str}")
    print()
    
    # ============================================
    # PRESCRIBED ACTIVITIES (field_1683)
    # ============================================
    print("📋 PRESCRIBED ACTIVITIES (field_1683):")
    prescribed_field = student.get('field_1683') or student.get('field_1683_raw') or []
    
    print(f"   Raw field value type: {type(prescribed_field)}")
    print(f"   Raw field value: {prescribed_field[:500] if isinstance(prescribed_field, str) else prescribed_field}")
    print()
    
    prescribed_activities = []
    
    # Parse HTML format (most common)
    if isinstance(prescribed_field, str) and prescribed_field.strip():
        import re
        # Extract both Knack IDs (from class) and activity names (from text)
        pattern = r'<span class="([a-f0-9]{24})"[^>]*>([^<]+)</span>'
        matches = re.findall(pattern, prescribed_field)
        
        for knack_id, activity_name in matches:
            prescribed_activities.append({
                'name': activity_name.strip(),
                'knack_id': knack_id.strip()
            })
            print(f"   - Activity: name='{activity_name.strip()}', knack_id='{knack_id}'")
    
    # Parse list format (alternative)
    elif isinstance(prescribed_field, list):
        for item in prescribed_field:
            if isinstance(item, dict):
                activity_name = item.get('identifier') or item.get('name')
                activity_id = item.get('id')
                prescribed_activities.append({'name': activity_name, 'knack_id': activity_id})
                print(f"   - Activity: name='{activity_name}', knack_id='{activity_id}'")
            elif isinstance(item, str):
                if len(item) == 24:
                    prescribed_activities.append({'name': None, 'knack_id': item})
                    print(f"   - Activity: ID={item}")
                else:
                    prescribed_activities.append({'name': item, 'knack_id': None})
                    print(f"   - Activity: name='{item}'")
    
    print(f"\n   Total prescribed: {len(prescribed_activities)}")
    
    # Try to resolve to Supabase UUIDs
    print("\n   🔄 Resolving to Supabase UUIDs:")
    for activity_info in prescribed_activities[:5]:  # Test first 5
        activity_uuid = None
        
        if activity_info['name']:
            activity_uuid = get_activity_id_by_name(activity_info['name'])
            if activity_uuid:
                print(f"      ✅ '{activity_info['name']}' → {activity_uuid}")
            else:
                print(f"      ❌ '{activity_info['name']}' NOT FOUND in Supabase")
        
        if not activity_uuid and activity_info['knack_id']:
            activity_uuid, name = get_activity_id_by_knack_id(activity_info['knack_id'])
            if activity_uuid:
                print(f"      ✅ ID {activity_info['knack_id']} → {activity_uuid} ({name})")
            else:
                print(f"      ❌ ID {activity_info['knack_id']} NOT FOUND in Supabase")
    
    # ============================================
    # FINISHED ACTIVITIES (field_1380)
    # ============================================
    print("\n\n✅ FINISHED ACTIVITIES (field_1380):")
    finished_field = student.get('field_1380') or student.get('field_1380_raw') or ''
    
    print(f"   Raw field value: {finished_field}")
    
    finished_ids = []
    if isinstance(finished_field, str) and finished_field.strip():
        finished_ids = [aid.strip() for aid in finished_field.split(',') if aid.strip()]
    
    print(f"   Total finished: {len(finished_ids)}")
    
    if finished_ids:
        print("\n   🔄 Resolving to Supabase UUIDs:")
        for knack_id in finished_ids[:5]:  # Test first 5
            activity_uuid, name = get_activity_id_by_knack_id(knack_id)
            if activity_uuid:
                print(f"      ✅ {knack_id} → {activity_uuid} ({name})")
            else:
                print(f"      ❌ {knack_id} NOT FOUND in Supabase")
    
    # ============================================
    # STUDENT-ADDED (field_3580)
    # ============================================
    print("\n\n👤 STUDENT-ADDED ACTIVITIES (field_3580):")
    student_added = student.get('field_3580') or student.get('field_3580_raw') or ''
    print(f"   Raw field value: {student_added}")
    
    student_added_ids = []
    if isinstance(student_added, str) and student_added.strip():
        student_added_ids = [aid.strip() for aid in student_added.split(',') if aid.strip()]
    
    print(f"   Total student-added: {len(student_added_ids)}")
    
    # ============================================
    # STAFF-ADDED (field_3581)
    # ============================================
    print("\n\n👨‍🏫 STAFF-ADDED ACTIVITIES (field_3581):")
    staff_added = student.get('field_3581') or student.get('field_3581_raw') or ''
    print(f"   Raw field value: {staff_added}")
    
    staff_added_ids = []
    if isinstance(staff_added, str) and staff_added.strip():
        staff_added_ids = [aid.strip() for aid in staff_added.split(',') if aid.strip()]
    
    print(f"   Total staff-added: {len(staff_added_ids)}")
    
    # ============================================
    # PREFERENCES
    # ============================================
    print("\n\n⚙️ PREFERENCES:")
    completed_one = student.get('field_2335') or student.get('field_2335_raw')
    notifications_on = student.get('field_1810') or student.get('field_1810_raw')
    
    print(f"   field_2335 (Completed One Activity): {completed_one}")
    print(f"   field_1810 (Notifications On/Off): {notifications_on}")
    
    # ============================================
    # SUMMARY
    # ============================================
    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print(f"✅ Prescribed: {len(prescribed_activities)}")
    print(f"✅ Finished: {len(finished_ids)}")
    print(f"👤 Student-Added: {len(student_added_ids)}")
    print(f"👨‍🏫 Staff-Added: {len(staff_added_ids)}")
    print()
    print("🎯 The main migration script (06_migrate_student_activities.py) should work!")
    print("   Run it to sync ALL students.")
    print()


if __name__ == "__main__":
    test_sync()

