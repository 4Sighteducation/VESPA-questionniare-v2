"""
Quick fix: Assign roles to staff who don't have them
Reads from knack_user_attributes JSONB to get roles
"""
import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from supabase import create_client

env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')
VESPA_ACADEMY_ID = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

print("=" * 80)
print("🔧 Assigning Missing Roles to VESPA ACADEMY Staff")
print("=" * 80)
print()

# Get all VESPA ACADEMY staff WITHOUT roles
staff = supabase.table('vespa_accounts')\
    .select('id, email, full_name, knack_user_attributes')\
    .eq('school_id', VESPA_ACADEMY_ID)\
    .eq('account_type', 'staff')\
    .execute()

print(f"✅ Found {len(staff.data)} staff accounts")

# Filter to those WITHOUT roles
staff_without_roles = []
for s in staff.data:
    roles_check = supabase.table('user_roles')\
        .select('id').eq('account_id', s['id']).execute()
    
    if not roles_check.data:
        staff_without_roles.append(s)

print(f"⚠️  {len(staff_without_roles)} staff missing roles")
print()

if not staff_without_roles:
    print("✅ All staff have roles!")
    sys.exit(0)

# Assign roles based on knack_user_attributes
created = 0
errors = 0

for staff_member in staff_without_roles:
    email = staff_member['email']
    knack_attrs = staff_member.get('knack_user_attributes', {})
    
    if not knack_attrs or 'roles' not in knack_attrs:
        print(f"⚠️  {email}: No roles in knack_user_attributes")
        continue
    
    roles = knack_attrs.get('roles', [])
    print(f"Processing {email}: {roles}")
    
    for role in roles:
        if role == 'Student':
            continue  # Skip student role for staff
        
        role_type = None
        role_data = {}
        
        if role == 'Staff Admin':
            role_type = 'staff_admin'
            role_data = {'admin_level': 'full'}
        elif role == 'Tutor':
            role_type = 'tutor'
            role_data = {}
        elif role == 'Head of Year':
            role_type = 'head_of_year'
            role_data = {}
        elif role == 'Subject Teacher':
            role_type = 'subject_teacher'
            role_data = {}
        elif role == 'General Staff':
            role_type = 'general_staff'
            role_data = {'access_level': 'view_only'}
        elif role == 'Head of Department':
            role_type = 'head_of_department'
            role_data = {}
        
        if role_type:
            try:
                result = supabase.rpc('assign_staff_role', {
                    'email_param': email,
                    'role_type_param': role_type,
                    'role_data_param': role_data,
                    'is_primary_param': len(roles) == 1
                }).execute()
                print(f"  ✅ Assigned {role_type} to {email}")
                created += 1
            except Exception as e:
                print(f"  ❌ Error: {e}")
                errors += 1

print()
print("=" * 80)
print(f"✅ Roles assigned: {created}")
print(f"❌ Errors: {errors}")
print("=" * 80)

