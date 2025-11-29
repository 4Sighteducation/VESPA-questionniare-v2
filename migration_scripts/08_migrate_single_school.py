"""
Single School Re-Migration Script
Purpose: Re-migrate a specific school after changes in Knack
Usage: python 08_migrate_single_school.py "School Name"
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from supabase import create_client
import requests
import json
from datetime import datetime
import time
import re

# Load environment
env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')
KNACK_APP_ID = os.getenv('KNACK_APP_ID')
KNACK_API_KEY = os.getenv('KNACK_API_KEY')

BATCH_SIZE = 100
RATE_LIMIT_DELAY = 0.5

# Get school name from command line or use default
SCHOOL_NAME = sys.argv[1] if len(sys.argv) > 1 else "Nord Anglia School - Dubai"

print("=" * 80)
print(f"🔄 RE-MIGRATING SINGLE SCHOOL")
print("=" * 80)
print(f"School: {SCHOOL_NAME}")
print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print()

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
print("✅ Supabase connected\n")

# Profile mapping
PROFILE_TO_ROLE = {
    'profile_6': 'Student',
    'profile_5': 'Staff Admin',
    'profile_7': 'Tutor',
    'profile_18': 'Head of Year',
    'profile_78': 'Subject Teacher'
}

def extract_email_from_html(html_string):
    """Extract email from HTML"""
    if not html_string:
        return None
    if '@' in html_string and '<' not in html_string:
        return html_string
    match = re.search(r'mailto:([^"]+)', html_string)
    if match:
        return match.group(1)
    match = re.search(r'>([^<]+@[^<]+)<', html_string)
    if match:
        return match.group(1)
    return html_string

def normalize_account_type(raw_value):
    """Normalize account types"""
    if not raw_value or raw_value.strip() == '':
        return 'COACHING PORTAL'
    raw_upper = raw_value.upper().strip()
    if any(keyword in raw_upper for keyword in ['COACHING', 'GOLD', 'SILVER', 'BRONZE']):
        return 'COACHING PORTAL'
    if 'RESOURCE' in raw_upper:
        return 'RESOURCE PORTAL'
    return raw_value

def get_knack_records(object_key, filters=None):
    """Fetch records from Knack with pagination"""
    url = f"https://api.knack.com/v1/objects/{object_key}/records"
    headers = {
        'X-Knack-Application-Id': KNACK_APP_ID,
        'X-Knack-REST-API-KEY': KNACK_API_KEY,
        'Content-Type': 'application/json'
    }
    
    all_records = []
    page = 1
    
    while True:
        params = {'page': page, 'rows_per_page': 1000}
        if filters:
            params['filters'] = json.dumps(filters)
        
        try:
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()
            data = response.json()
            
            records = data.get('records', [])
            total_pages = data.get('total_pages', 1)
            all_records.extend(records)
            
            if page >= total_pages:
                break
            page += 1
            time.sleep(0.2)
        except Exception as e:
            print(f"❌ API Error: {e}")
            break
    
    return all_records

# Step 1: Get school from Supabase
print("🔍 Finding school in Supabase...")
school = supabase.table('establishments')\
    .select('id, knack_id, name')\
    .ilike('name', f'%{SCHOOL_NAME}%')\
    .execute()

if not school.data:
    print(f"❌ School not found: {SCHOOL_NAME}")
    print("\nAvailable schools (matching 'Nord Anglia'):")
    all_schools = supabase.table('establishments')\
        .select('name')\
        .ilike('name', '%nord anglia%')\
        .execute()
    for s in all_schools.data:
        print(f"   - {s['name']}")
    sys.exit(1)

school = school.data[0]
school_id = school['id']
school_knack_id = school['knack_id']
school_name = school['name']

print(f"✅ Found: {school_name}")
print(f"   Supabase ID: {school_id}")
print(f"   Knack ID: {school_knack_id}")
print()

# Step 2: Clean existing data
print("🧹 Cleaning existing data for this school...")

# Get all account IDs for this school first
accounts_to_delete = supabase.table('vespa_accounts')\
    .select('id').eq('school_id', school_id).execute()
account_ids = [acc['id'] for acc in accounts_to_delete.data]

if account_ids:
    print(f"   Found {len(account_ids)} existing accounts to clean")
    
    # Delete connections
    deleted = supabase.table('user_connections')\
        .delete().in_('student_account_id', account_ids).execute()
    print(f"   ✅ Deleted connections")
    
    # Delete roles
    deleted = supabase.table('user_roles')\
        .delete().in_('account_id', account_ids).execute()
    print(f"   ✅ Deleted roles")
    
    # Delete staff
    deleted = supabase.table('vespa_staff')\
        .delete().eq('school_id', school_id).execute()
    print(f"   ✅ Deleted staff")
    
    # Delete students
    deleted = supabase.table('vespa_students')\
        .delete().eq('school_id', school_id).execute()
    print(f"   ✅ Deleted students")
    
    # Delete accounts
    deleted = supabase.table('vespa_accounts')\
        .delete().eq('school_id', school_id).execute()
    print(f"   ✅ Deleted accounts")
else:
    print("   No existing data to clean")

print()

# Step 3: Fetch accounts from Knack
print("📥 Fetching accounts from Knack Object_3...")
filters = {
    'match': 'and',
    'rules': [
        {'field': 'field_122', 'operator': 'is', 'value': school_knack_id}
    ]
}

accounts = get_knack_records('object_3', filters=filters)
print(f"   Found {len(accounts)} accounts\n")

if not accounts:
    print("⚠️  No accounts found")
    sys.exit(0)

# Step 4: Process accounts
print("📝 Processing accounts...")
students_to_insert = []
staff_to_insert = []
roles_to_assign = []

for idx, account in enumerate(accounts, 1):
    if idx % 50 == 0:
        print(f"   {idx}/{len(accounts)}...")
    
    try:
        # Extract email
        email_raw = account.get('field_70_raw', {})
        email = email_raw.get('email') if isinstance(email_raw, dict) else account.get('field_70')
        if not email:
            continue
        
        # Get roles
        profile_ids = account.get('field_73_raw', [])
        roles = [PROFILE_TO_ROLE.get(pid, pid) for pid in profile_ids]
        
        # Extract name
        name_raw = account.get('field_69_raw', {})
        if isinstance(name_raw, dict):
            full_name = name_raw.get('full', '')
            first_name = name_raw.get('first', '')
            last_name = name_raw.get('last', '')
            title = name_raw.get('title', '')
            
            # Clean establishment name from full name if present
            # Some Knack records have "School Name First Last" format
            if school_name in full_name:
                full_name = full_name.replace(school_name, '').strip()
            
            # Rebuild if needed
            if not full_name and (first_name or last_name):
                full_name = f"{title} {first_name} {last_name}".strip()
            
            name_parts = {
                'title': title,
                'first': first_name,
                'last': last_name,
                'full': full_name
            }
        else:
            full = str(name_raw) if name_raw else ''
            # Clean establishment name
            if school_name in full:
                full = full.replace(school_name, '').strip()
            parts = full.split()
            name_parts = {
                'title': '',
                'first': parts[0] if parts else '',
                'last': ' '.join(parts[1:]) if len(parts) > 1 else '',
                'full': full
            }
        
        account_type_raw = account.get('field_441')
        account_type = normalize_account_type(account_type_raw)
        
        is_student = 'Student' in roles
        is_staff = any(r in ['Staff Admin', 'Tutor', 'Head of Year', 'Subject Teacher',
                             'Head of Department', 'General Staff'] for r in roles)
        
        # Staff takes precedence
        if is_staff:
            account_type_for_creation = 'staff'
        elif is_student:
            account_type_for_creation = 'student'
        else:
            continue
        
        knack_attrs = {
            'id': account.get('id'),
            'email': email,
            'roles': roles,
            'profile_ids': profile_ids,
            'account_type': account_type_raw
        }
        
        # Create account
        account_result = supabase.rpc('get_or_create_account', {
            'email_param': email,
            'account_type_param': account_type_for_creation,
            'knack_attributes': knack_attrs
        }).execute()
        
        account_id = account_result.data
        
        # Update account
        supabase.table('vespa_accounts').update({
            'first_name': name_parts['first'],
            'last_name': name_parts['last'],
            'full_name': name_parts['full'],
            'school_id': school_id,
            'school_name': school_name,
            'preferences': {
                'language': account.get('field_2251', 'en'),
                'notifications_enabled': True
            }
        }).eq('id', account_id).execute()
        
        # Collect students
        if is_student:
            students_to_insert.append({
                'email': email,
                'account_id': account_id,
                'school_id': school_id,
                'school_name': school_name,
                'current_knack_id': account.get('id'),
                'first_name': name_parts['first'],
                'last_name': name_parts['last'],
                'full_name': name_parts['full'],
                'current_year_group': account.get('field_550'),
                'student_group': account.get('field_708'),
                'current_academic_year': '2025/2026',
                'current_level': 'Level 2',
                'current_cycle': 1,
                'status': 'active',
                'is_active': True,
                'sis_student_id': account.get('field_3129'),
                'knack_user_attributes': knack_attrs,
                'last_synced_from_knack': datetime.now().isoformat()
            })
        
        # Collect staff
        if is_staff:
            staff_to_insert.append({
                'email': email,
                'account_id': account_id,
                'school_id': school_id,
                'school_name': school_name,
                'department': account.get('field_551'),
                'position_title': name_parts['title'],
                'active_academic_year': '2025/2026'
            })
            
            # Collect roles
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
                elif role == 'Head of Department':
                    role_type = 'head_of_department'
                    role_data = {'department': account.get('field_551')}
                
                if role_type:
                    roles_to_assign.append({
                        'email': email,
                        'role_type': role_type,
                        'role_data': role_data,
                        'is_primary': len([r for r in roles if r != 'Student']) == 1
                    })
    
    except Exception as e:
        print(f"   ❌ Error: {email}: {e}")
        continue

# Batch inserts
if students_to_insert:
    print(f"\n👥 Inserting {len(students_to_insert)} students...")
    for i in range(0, len(students_to_insert), BATCH_SIZE):
        batch = students_to_insert[i:i+BATCH_SIZE]
        try:
            supabase.table('vespa_students').insert(batch).execute()
            print(f"   Batch {(i//BATCH_SIZE)+1}: ✅")
            time.sleep(RATE_LIMIT_DELAY)
        except Exception as e:
            print(f"   ❌ Error: {e}")

if staff_to_insert:
    print(f"\n👨‍🏫 Inserting {len(staff_to_insert)} staff...")
    for i in range(0, len(staff_to_insert), BATCH_SIZE):
        batch = staff_to_insert[i:i+BATCH_SIZE]
        try:
            supabase.table('vespa_staff').insert(batch).execute()
            print(f"   Batch {(i//BATCH_SIZE)+1}: ✅")
            time.sleep(RATE_LIMIT_DELAY)
        except Exception as e:
            print(f"   ❌ Error: {e}")

if roles_to_assign:
    print(f"\n🎭 Assigning {len(roles_to_assign)} roles...")
    for idx, role in enumerate(roles_to_assign, 1):
        if idx % 50 == 0:
            print(f"   {idx}/{len(roles_to_assign)}...")
        try:
            supabase.rpc('assign_staff_role', {
                'email_param': role['email'],
                'role_type_param': role['role_type'],
                'role_data_param': role['role_data'],
                'is_primary_param': role['is_primary']
            }).execute()
            if idx % 50 == 0:
                time.sleep(0.1)
        except Exception as e:
            print(f"   ❌ {role['email']}: {e}")

# Build connections
print(f"\n🔗 Building connections from Object_6...")
filters = {
    'match': 'and',
    'rules': [
        {'field': 'field_179', 'operator': 'is', 'value': school_knack_id}
    ]
}

students = get_knack_records('object_6', filters=filters)
print(f"   Found {len(students)} students in Object_6")

# Get account map
all_accounts = supabase.table('vespa_accounts')\
    .select('id, email').eq('school_id', school_id).execute()
account_map = {acc['email']: acc['id'] for acc in all_accounts.data}

connections_to_create = []

for student in students:
    try:
        student_email_raw = student.get('field_91_raw', {})
        student_email = student_email_raw.get('email') if isinstance(student_email_raw, dict) \
                       else extract_email_from_html(student.get('field_91', ''))
        
        if not student_email or student_email not in account_map:
            continue
        
        # Extract connections
        for field, conn_type in [
            ('field_190_raw', 'staff_admin'),
            ('field_1682_raw', 'tutor'),
            ('field_547_raw', 'head_of_year'),
            ('field_2177_raw', 'subject_teacher')
        ]:
            connections_raw = student.get(field, [])
            for conn in connections_raw:
                if isinstance(conn, dict):
                    staff_email = extract_email_from_html(conn.get('identifier'))
                    if staff_email and staff_email in account_map:
                        connections_to_create.append({
                            'staff_email': staff_email,
                            'student_email': student_email,
                            'type': conn_type
                        })
    except Exception as e:
        continue

# Create connections
created = 0
if connections_to_create:
    print(f"   Creating {len(connections_to_create)} connections...")
    for conn in connections_to_create:
        try:
            supabase.rpc('create_staff_student_connection', {
                'staff_email_param': conn['staff_email'],
                'student_email_param': conn['student_email'],
                'connection_type_param': conn['type'],
                'context_param': {}
            }).execute()
            created += 1
            if created % 100 == 0:
                print(f"      {created}/{len(connections_to_create)}...")
                time.sleep(0.1)
        except Exception as e:
            pass
    
    print(f"   ✅ {created} connections created")

# Verification
print("\n" + "=" * 80)
print("🔍 VERIFICATION")
print("=" * 80)

# Count what was actually created
accounts_count = supabase.table('vespa_accounts').select('id', count='exact').eq('school_id', school_id).execute()
students_count = supabase.table('vespa_students').select('id', count='exact').eq('school_id', school_id).execute()
staff_count = supabase.table('vespa_staff').select('id', count='exact').eq('school_id', school_id).execute()

print(f"✅ Accounts created: {accounts_count.count}")
print(f"✅ Students created: {students_count.count}")
print(f"✅ Staff created: {staff_count.count}")
print(f"✅ Roles attempted: {len(roles_to_assign)}")
print(f"✅ Connections attempted: {len(connections_to_create)}")
print(f"✅ Connections created: {created if 'created' in locals() else 0}")
print()
print("=" * 80)
print(f"✅ {school_name} MIGRATION COMPLETE!")
print("=" * 80)

