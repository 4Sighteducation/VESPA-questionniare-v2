"""
Migration Script: VESPA ACADEMY Complete Migration
Purpose: Migrate VESPA ACADEMY accounts from Object_3 + connections from Object_6
Status: TEST VERSION - Safe to run multiple times
Version: 2.0 - Complete field mappings
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from supabase import create_client
import requests
import json
from datetime import datetime

# Load environment variables
env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

# Configuration
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')
KNACK_APP_ID = os.getenv('KNACK_APP_ID', '66e26296d863e5001c6f1e09')
KNACK_API_KEY = os.getenv('KNACK_API_KEY', '0b19dcb0-9f43-11ef-8724-eb3bc75b770f')

# VESPA ACADEMY
VESPA_ACADEMY_ID = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
VESPA_ACADEMY_KNACK_ID = '603e9f97cb8481001b31183d'

print("=" * 80)
print("🧪 VESPA ACADEMY COMPLETE MIGRATION (Object_3 + Object_6)")
print("=" * 80)
print(f"Supabase: {SUPABASE_URL}")
print(f"VESPA ACADEMY: {VESPA_ACADEMY_ID}")
print()

# Initialize Supabase
try:
    supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    print("✅ Supabase client initialized")
except Exception as e:
    print(f"❌ Failed to initialize Supabase: {e}")
    sys.exit(1)


def get_knack_records(object_key, filters=None, page=1, rows_per_page=1000):
    """Fetch records from Knack API with pagination"""
    url = f"https://api.knack.com/v1/objects/{object_key}/records"
    headers = {
        'X-Knack-Application-Id': KNACK_APP_ID,
        'X-Knack-REST-API-KEY': KNACK_API_KEY,
        'Content-Type': 'application/json'
    }
    
    params = {'page': page, 'rows_per_page': rows_per_page}
    if filters:
        params['filters'] = json.dumps(filters)
    
    try:
        response = requests.get(url, headers=headers, params=params)
        response.raise_for_status()
        data = response.json()
        
        records = data.get('records', [])
        total_pages = data.get('total_pages', 1)
        
        # Fetch remaining pages
        for page_num in range(2, total_pages + 1):
            params['page'] = page_num
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()
            records.extend(response.json().get('records', []))
        
        return records
    except Exception as e:
        print(f"❌ Error fetching from Knack: {e}")
        return []


def normalize_account_type(raw_value):
    """Normalize legacy account types to standard values"""
    if not raw_value or raw_value.strip() == '':
        return None  # Will be flagged for review
    
    raw_upper = raw_value.upper().strip()
    
    # COACHING PORTAL variations
    if any(keyword in raw_upper for keyword in ['COACHING', 'GOLD', 'SILVER', 'BRONZE']):
        return 'COACHING PORTAL'
    
    # RESOURCE PORTAL variations
    if 'RESOURCE' in raw_upper:
        return 'RESOURCE PORTAL'
    
    # Already normalized
    if raw_upper in ['COACHING PORTAL', 'RESOURCE PORTAL']:
        return raw_value
    
    # Unknown - return as-is but flag
    return raw_value


def extract_name_parts(name_field):
    """Extract title, first, last from Knack person field"""
    if not name_field:
        return {'title': None, 'first': None, 'last': None, 'full': None}
    
    return {
        'title': name_field.get('title'),
        'first': name_field.get('first'),
        'last': name_field.get('last'),
        'full': name_field.get('full') or f"{name_field.get('first', '')} {name_field.get('last', '')}".strip()
    }


def migrate_accounts_from_object3():
    """
    Phase 1: Import all VESPA ACADEMY accounts from Object_3
    Creates vespa_accounts, vespa_students (if Student), vespa_staff (if staff role)
    """
    print("\n" + "=" * 80)
    print("📚 PHASE 1: Migrating Accounts from Object_3")
    print("=" * 80)
    
    # Filter for VESPA ACADEMY, Active, Non-Dummy, Non-Deleted
    filters = {
        'match': 'and',
        'rules': [
            {'field': 'field_122', 'operator': 'is', 'value': VESPA_ACADEMY_KNACK_ID},
            {'field': 'field_72', 'operator': 'is not', 'value': 'Inactive'},
            {'field': 'field_2082', 'operator': 'is not', 'value': True},  # Not dummy
            {'field': 'field_2659', 'operator': 'is not', 'value': True}   # Not deleted
        ]
    }
    
    accounts = get_knack_records('object_3', filters=filters)
    print(f"✅ Found {len(accounts)} VESPA ACADEMY accounts in Knack Object_3")
    
    if not accounts:
        print("⚠️  No accounts found!")
        return {}
    
    stats = {
        'total': len(accounts),
        'students_created': 0,
        'staff_created': 0,
        'multi_role': 0,
        'skipped': 0,
        'errors': 0,
        'flagged_for_review': []
    }
    
    # Store for connection building
    account_connections = {}
    
    for account in accounts:
        try:
            email = account.get('field_70')
            if not email:
                print(f"⚠️  Skip: No email for account {account.get('id')}")
                stats['skipped'] += 1
                continue
            
            # Extract core data
            roles = account.get('field_73', [])
            name_parts = extract_name_parts(account.get('field_69'))
            account_type_raw = account.get('field_441')
            account_type = normalize_account_type(account_type_raw)
            
            # Flag if account type is missing/unusual
            if not account_type:
                stats['flagged_for_review'].append({
                    'email': email,
                    'reason': 'missing_account_type',
                    'raw_value': account_type_raw
                })
                account_type = 'COACHING PORTAL'  # Default
            
            # Determine if student, staff, or both
            is_student = 'Student' in roles
            is_staff = any(role in ['Staff Admin', 'Tutor', 'Head of Year', 'Subject Teacher', 
                                    'Head of Department', 'General Staff'] for role in roles)
            
            if is_student and is_staff:
                stats['multi_role'] += 1
            
            # Build knack_attributes
            knack_attrs = {
                'id': account.get('id'),
                'email': email,
                'roles': roles,
                'account_type': account_type_raw
            }
            
            # Create vespa_account
            account_result = supabase.rpc('get_or_create_account', {
                'email_param': email,
                'account_type_param': 'student' if is_student else 'staff',
                'knack_attributes': knack_attrs
            }).execute()
            
            account_id = account_result.data
            
            # Update vespa_accounts with full data
            supabase.table('vespa_accounts').update({
                'first_name': name_parts['first'],
                'last_name': name_parts['last'],
                'full_name': name_parts['full'],
                'school_id': VESPA_ACADEMY_ID,
                'school_name': 'VESPA ACADEMY',
                'preferences': {
                    'language': account.get('field_2251', 'en'),
                    'notifications_enabled': True
                }
            }).eq('id', account_id).execute()
            
            # Create vespa_students entry if Student role
            if is_student:
                # Check if already exists
                existing = supabase.table('vespa_students')\
                    .select('id').eq('email', email).execute()
                
                if not existing.data:
                    supabase.table('vespa_students').insert({
                        'email': email,
                        'account_id': account_id,
                        'school_id': VESPA_ACADEMY_ID,
                        'school_name': 'VESPA ACADEMY',
                        'current_knack_id': account.get('id'),
                        'first_name': name_parts['first'],
                        'last_name': name_parts['last'],
                        'full_name': name_parts['full'],
                        'current_year_group': account.get('field_550'),
                        'student_group': account.get('field_708'),
                        'current_academic_year': '2025/2026',  # Default current year
                        'current_level': 'Level 2',
                        'current_cycle': 1,
                        'status': 'active',
                        'is_active': True,
                        'sis_student_id': account.get('field_3129'),
                        'knack_user_attributes': knack_attrs,
                        'last_synced_from_knack': datetime.now().isoformat()
                    }).execute()
                    
                    stats['students_created'] += 1
                    print(f"✅ Student: {email}")
                else:
                    print(f"⏭️  Student exists: {email}")
            
            # Create vespa_staff entry if staff role(s)
            if is_staff:
                # Check if already exists
                existing = supabase.table('vespa_staff')\
                    .select('id').eq('email', email).execute()
                
                if not existing.data:
                    supabase.table('vespa_staff').insert({
                        'email': email,
                        'account_id': account_id,
                        'school_id': VESPA_ACADEMY_ID,
                        'school_name': 'VESPA ACADEMY',
                        'department': account.get('field_551'),  # Subject
                        'position_title': name_parts['title'],
                        'active_academic_year': '2025/2026'
                    }).execute()
                    
                    stats['staff_created'] += 1
                    print(f"✅ Staff: {email} ({', '.join([r for r in roles if r != 'Student'])})")
                    
                    # Create user_roles for each staff role
                    for role in roles:
                        role_type = None
                        role_data = {}
                        
                        if role == 'Staff Admin':
                            role_type = 'staff_admin'
                            role_data = {'admin_level': 'full'}
                        elif role == 'Tutor':
                            role_type = 'tutor'
                            role_data = {
                                'tutor_group': account.get('field_708'),
                                'year_group': account.get('field_550')
                            }
                        elif role == 'Head of Year':
                            role_type = 'head_of_year'
                            role_data = {'year_group': account.get('field_550')}
                        elif role == 'Subject Teacher':
                            role_type = 'subject_teacher'
                            role_data = {
                                'subject': account.get('field_551'),
                                'subject_code': account.get('field_2178'),
                                'teaching_group': account.get('field_129')
                            }
                        elif role == 'General Staff':
                            role_type = 'general_staff'
                            role_data = {'access_level': 'view_only'}
                        
                        if role_type:
                            supabase.rpc('assign_staff_role', {
                                'email_param': email,
                                'role_type_param': role_type,
                                'role_data_param': role_data,
                                'is_primary_param': len([r for r in roles if r != 'Student']) == 1
                            }).execute()
                else:
                    print(f"⏭️  Staff exists: {email}")
        
        except Exception as e:
            print(f"❌ Error: {email} - {e}")
            stats['errors'] += 1
            continue
    
    return stats


def build_connections_from_object6():
    """
    Phase 2: Build user_connections from Object_6 student records
    Extract connections from field_190, field_1682, field_547, field_2177
    """
    print("\n" + "=" * 80)
    print("🔗 PHASE 2: Building Connections from Object_6")
    print("=" * 80)
    
    # Get VESPA ACADEMY students from Object_6
    # We only need connection fields, not full student data
    filters = {
        'match': 'and',
        'rules': [
            {'field': 'field_179', 'operator': 'is', 'value': VESPA_ACADEMY_KNACK_ID}
        ]
    }
    
    students = get_knack_records('object_6', filters=filters)
    print(f"✅ Found {len(students)} VESPA ACADEMY students in Object_6")
    
    stats = {
        'staff_admin_connections': 0,
        'tutor_connections': 0,
        'hoy_connections': 0,
        'teacher_connections': 0,
        'errors': 0
    }
    
    for student in students:
        try:
            student_email = student.get('field_91')
            if not student_email:
                continue
            
            # Get student account_id
            student_account = supabase.table('vespa_accounts')\
                .select('id').eq('email', student_email).execute()
            
            if not student_account.data:
                print(f"⚠️  Student not in vespa_accounts: {student_email}")
                continue
            
            student_account_id = student_account.data[0]['id']
            
            # Extract connection arrays from Object_6
            staff_admins = student.get('field_190', [])  # Array of staff admin records
            tutors = student.get('field_1682', [])       # Array of tutor records
            hoys = student.get('field_547', [])          # Array of HOY records
            teachers = student.get('field_2177', [])     # Array of teacher records
            
            # Create connections for each staff type
            # Note: Knack connections can be either email strings or objects with 'id' and 'identifier' (email)
            
            # Staff Admins
            for staff in staff_admins:
                staff_email = staff if isinstance(staff, str) else staff.get('identifier') or staff.get('email')
                if staff_email:
                    try:
                        supabase.rpc('create_staff_student_connection', {
                            'staff_email_param': staff_email,
                            'student_email_param': student_email,
                            'connection_type_param': 'staff_admin',
                            'context_param': {}
                        }).execute()
                        stats['staff_admin_connections'] += 1
                    except Exception as e:
                        if 'not found' not in str(e).lower():
                            print(f"⚠️  Staff admin not found: {staff_email}")
            
            # Tutors
            for tutor in tutors:
                tutor_email = tutor if isinstance(tutor, str) else tutor.get('identifier') or tutor.get('email')
                if tutor_email:
                    try:
                        supabase.rpc('create_staff_student_connection', {
                            'staff_email_param': tutor_email,
                            'student_email_param': student_email,
                            'connection_type_param': 'tutor',
                            'context_param': {'tutor_group': student.get('field_708')}
                        }).execute()
                        stats['tutor_connections'] += 1
                    except Exception as e:
                        if 'not found' not in str(e).lower():
                            print(f"⚠️  Tutor not found: {tutor_email}")
            
            # Heads of Year
            for hoy in hoys:
                hoy_email = hoy if isinstance(hoy, str) else hoy.get('identifier') or hoy.get('email')
                if hoy_email:
                    try:
                        supabase.rpc('create_staff_student_connection', {
                            'staff_email_param': hoy_email,
                            'student_email_param': student_email,
                            'connection_type_param': 'head_of_year',
                            'context_param': {'year_group': student.get('field_550')}
                        }).execute()
                        stats['hoy_connections'] += 1
                    except Exception as e:
                        if 'not found' not in str(e).lower():
                            print(f"⚠️  HOY not found: {hoy_email}")
            
            # Subject Teachers
            for teacher in teachers:
                teacher_email = teacher if isinstance(teacher, str) else teacher.get('identifier') or teacher.get('email')
                if teacher_email:
                    try:
                        supabase.rpc('create_staff_student_connection', {
                            'staff_email_param': teacher_email,
                            'student_email_param': student_email,
                            'connection_type_param': 'subject_teacher',
                            'context_param': {}
                        }).execute()
                        stats['teacher_connections'] += 1
                    except Exception as e:
                        if 'not found' not in str(e).lower():
                            print(f"⚠️  Teacher not found: {teacher_email}")
        
        except Exception as e:
            print(f"❌ Error processing connections for {student_email}: {e}")
            stats['errors'] += 1
            continue
    
    return stats


def verify_migration():
    """Verify the complete migration"""
    print("\n" + "=" * 80)
    print("🔍 VERIFICATION")
    print("=" * 80)
    
    # Check accounts
    accounts = supabase.table('vespa_accounts')\
        .select('id, email, account_type').eq('school_id', VESPA_ACADEMY_ID).execute()
    print(f"✅ vespa_accounts: {len(accounts.data)} total")
    
    students_count = len([a for a in accounts.data if a['account_type'] == 'student'])
    staff_count = len([a for a in accounts.data if a['account_type'] == 'staff'])
    print(f"   - Students: {students_count}")
    print(f"   - Staff: {staff_count}")
    
    # Check students
    students = supabase.table('vespa_students')\
        .select('id').eq('school_id', VESPA_ACADEMY_ID).execute()
    print(f"✅ vespa_students: {len(students.data)}")
    
    # Check staff
    staff = supabase.table('vespa_staff')\
        .select('id').eq('school_id', VESPA_ACADEMY_ID).execute()
    print(f"✅ vespa_staff: {len(staff.data)}")
    
    # Check roles
    roles = supabase.table('user_roles')\
        .select('role_type').execute()
    vespa_academy_roles = [r for r in roles.data]
    print(f"✅ user_roles: {len(vespa_academy_roles)}")
    if vespa_academy_roles:
        role_counts = {}
        for r in vespa_academy_roles:
            role_type = r['role_type']
            role_counts[role_type] = role_counts.get(role_type, 0) + 1
        for role_type, count in role_counts.items():
            print(f"   - {role_type}: {count}")
    
    # Check connections
    connections = supabase.table('user_connections')\
        .select('connection_type').execute()
    print(f"✅ user_connections: {len(connections.data)}")
    if connections.data:
        conn_counts = {}
        for c in connections.data:
            conn_type = c['connection_type']
            conn_counts[conn_type] = conn_counts.get(conn_type, 0) + 1
        for conn_type, count in conn_counts.items():
            print(f"   - {conn_type}: {count}")
    
    # Check for orphans
    orphaned_accounts = supabase.table('vespa_accounts')\
        .select('email').eq('school_id', VESPA_ACADEMY_ID)\
        .eq('account_type', 'student').execute()
    
    linked_students = supabase.table('vespa_students')\
        .select('email').eq('school_id', VESPA_ACADEMY_ID).execute()
    
    orphaned_emails = set([a['email'] for a in orphaned_accounts.data]) - \
                     set([s['email'] for s in linked_students.data])
    
    if orphaned_emails:
        print(f"\n⚠️  Found {len(orphaned_emails)} orphaned accounts")
        for email in list(orphaned_emails)[:5]:
            print(f"   - {email}")
    else:
        print(f"\n✅ No orphaned accounts - all linked properly")


def main():
    """Main migration orchestrator"""
    try:
        # Phase 1: Import accounts
        account_stats = migrate_accounts_from_object3()
        
        print(f"\n📊 Phase 1 Summary:")
        print(f"  Total accounts processed: {account_stats['total']}")
        print(f"  Students created: {account_stats['students_created']}")
        print(f"  Staff created: {account_stats['staff_created']}")
        print(f"  Multi-role accounts: {account_stats['multi_role']}")
        print(f"  Skipped: {account_stats['skipped']}")
        print(f"  Errors: {account_stats['errors']}")
        
        if account_stats['flagged_for_review']:
            print(f"\n⚠️  {len(account_stats['flagged_for_review'])} accounts flagged for review:")
            for flag in account_stats['flagged_for_review'][:10]:
                print(f"   - {flag['email']}: {flag['reason']} (raw: {flag['raw_value']})")
        
        # Phase 2: Build connections
        if account_stats['students_created'] > 0 or account_stats['staff_created'] > 0:
            connection_stats = build_connections_from_object6()
            
            print(f"\n📊 Phase 2 Summary:")
            print(f"  Staff Admin connections: {connection_stats['staff_admin_connections']}")
            print(f"  Tutor connections: {connection_stats['tutor_connections']}")
            print(f"  HOY connections: {connection_stats['hoy_connections']}")
            print(f"  Teacher connections: {connection_stats['teacher_connections']}")
            print(f"  Total: {sum([v for k, v in connection_stats.items() if k != 'errors'])}")
            print(f"  Errors: {connection_stats['errors']}")
        
        # Verification
        verify_migration()
        
        print("\n" + "=" * 80)
        print("✅ VESPA ACADEMY MIGRATION COMPLETE!")
        print("=" * 80)
        print("\nNext steps:")
        print("  1. Test staff login - can they see their students?")
        print("  2. Test student login - can they access activities?")
        print("  3. Test activity assignment and completion")
        print("  4. Verify data isolation (no cross-school leakage)")
        print("  5. If successful → migrate all 127 establishments")
        print()
        
    except Exception as e:
        print(f"\n❌ Migration failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()

