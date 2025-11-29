"""
Migration Script: VESPA ACADEMY Test Migration
Purpose: Migrate ONLY VESPA ACADEMY students and staff to test the hybrid architecture
Status: TEST VERSION - Safe to run multiple times
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from supabase import create_client
import requests
import json
from datetime import datetime

# Load environment variables from DASHBOARD/.env
env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

# Supabase configuration
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')

# Knack configuration
KNACK_APP_ID = os.getenv('KNACK_APP_ID', '66e26296d863e5001c6f1e09')
KNACK_API_KEY = os.getenv('KNACK_API_KEY', '0b19dcb0-9f43-11ef-8724-eb3bc75b770f')

# VESPA ACADEMY establishment ID (from your query)
VESPA_ACADEMY_ID = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
VESPA_ACADEMY_KNACK_ID = '603e9f97cb8481001b31183d'

print("=" * 80)
print("🧪 VESPA ACADEMY TEST MIGRATION")
print("=" * 80)
print(f"Supabase URL: {SUPABASE_URL}")
print(f"VESPA ACADEMY ID: {VESPA_ACADEMY_ID}")
print()

# Initialize Supabase client
try:
    supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    print("✅ Supabase client initialized")
except Exception as e:
    print(f"❌ Failed to initialize Supabase: {e}")
    sys.exit(1)


def get_knack_records(object_key, filters=None, page=1, records_per_page=1000):
    """Fetch records from Knack API with pagination"""
    url = f"https://api.knack.com/v1/objects/{object_key}/records"
    headers = {
        'X-Knack-Application-Id': KNACK_APP_ID,
        'X-Knack-REST-API-KEY': KNACK_API_KEY,
        'Content-Type': 'application/json'
    }
    
    params = {
        'page': page,
        'rows_per_page': records_per_page
    }
    
    if filters:
        params['filters'] = json.dumps(filters)
    
    try:
        response = requests.get(url, headers=headers, params=params)
        response.raise_for_status()
        data = response.json()
        
        records = data.get('records', [])
        total_pages = data.get('total_pages', 1)
        
        # Fetch remaining pages
        if total_pages > 1:
            for page_num in range(2, total_pages + 1):
                params['page'] = page_num
                response = requests.get(url, headers=headers, params=params)
                response.raise_for_status()
                records.extend(response.json().get('records', []))
        
        return records
    except Exception as e:
        print(f"❌ Error fetching from Knack: {e}")
        return []


def migrate_vespa_academy_students():
    """Migrate VESPA ACADEMY students from Knack to Supabase"""
    print("\n" + "=" * 80)
    print("📚 STEP 1: Migrating VESPA ACADEMY Students")
    print("=" * 80)
    
    # Get VESPA ACADEMY students from Knack (Object_6)
    print("Fetching VESPA ACADEMY students from Knack...")
    
    # Filter for VESPA ACADEMY establishment (field_82 is the establishment connection)
    filters = {
        'match': 'and',
        'rules': [
            {
                'field': 'field_82',  # Establishment connection field
                'operator': 'is',
                'value': VESPA_ACADEMY_KNACK_ID
            }
        ]
    }
    
    knack_students = get_knack_records('object_6', filters=filters)
    print(f"✅ Found {len(knack_students)} VESPA ACADEMY students in Knack")
    
    if not knack_students:
        print("⚠️  No students found. Check the filter criteria.")
        return 0, 0
    
    migrated = 0
    skipped = 0
    errors = 0
    
    for student in knack_students:
        try:
            email = student.get('field_91')  # Student email field
            
            if not email:
                print(f"⚠️  Skip: No email for student {student.get('id')}")
                skipped += 1
                continue
            
            # Check if already in vespa_students
            existing = supabase.table('vespa_students')\
                .select('id, email')\
                .eq('email', email)\
                .execute()
            
            if existing.data:
                print(f"⏭️  Skip: {email} (already exists)")
                skipped += 1
                continue
            
            # Extract student data
            knack_attrs = {
                'id': student.get('id'),
                'email': email,
                'first_name': student.get('field_88', ''),  # First name
                'last_name': student.get('field_89', ''),   # Last name
                'name': student.get('field_90', ''),        # Full name
                'phone': student.get('field_92', ''),       # Phone
            }
            
            # Create in vespa_accounts using the helper function
            account_result = supabase.rpc('get_or_create_account', {
                'email_param': email,
                'account_type_param': 'student',
                'knack_attributes': knack_attrs
            }).execute()
            
            account_id = account_result.data
            
            # Update vespa_accounts with establishment info
            supabase.table('vespa_accounts')\
                .update({
                    'school_id': VESPA_ACADEMY_ID,
                    'school_name': 'VESPA ACADEMY'
                })\
                .eq('id', account_id)\
                .execute()
            
            # Create in vespa_students
            supabase.table('vespa_students').insert({
                'email': email,
                'account_id': account_id,
                'school_id': VESPA_ACADEMY_ID,
                'school_name': 'VESPA ACADEMY',
                'current_knack_id': student.get('id'),
                'first_name': student.get('field_88', ''),
                'last_name': student.get('field_89', ''),
                'full_name': student.get('field_90', ''),
                'current_year_group': student.get('field_112', ''),  # Year group
                'current_academic_year': student.get('field_204', '2025/2026'),
                'current_level': 'Level 2',  # Default
                'current_cycle': 1,
                'status': 'active',
                'is_active': True,
                'knack_user_attributes': knack_attrs,
                'last_synced_from_knack': datetime.now().isoformat()
            }).execute()
            
            print(f"✅ Migrated: {email}")
            migrated += 1
            
        except Exception as e:
            print(f"❌ Error migrating {email}: {e}")
            errors += 1
            continue
    
    print(f"\n📊 Migration Summary:")
    print(f"  ✅ Migrated: {migrated}")
    print(f"  ⏭️  Skipped: {skipped}")
    print(f"  ❌ Errors: {errors}")
    
    return migrated, skipped


def verify_migration():
    """Verify the migration was successful"""
    print("\n" + "=" * 80)
    print("🔍 STEP 2: Verifying Migration")
    print("=" * 80)
    
    # Check vespa_accounts
    accounts = supabase.table('vespa_accounts')\
        .select('id, email, school_name')\
        .eq('school_id', VESPA_ACADEMY_ID)\
        .execute()
    
    print(f"✅ vespa_accounts: {len(accounts.data)} VESPA ACADEMY students")
    
    # Check vespa_students
    students = supabase.table('vespa_students')\
        .select('id, email, school_name')\
        .eq('school_id', VESPA_ACADEMY_ID)\
        .execute()
    
    print(f"✅ vespa_students: {len(students.data)} VESPA ACADEMY students")
    
    # Check for orphaned accounts (in vespa_accounts but not vespa_students)
    orphaned = supabase.table('vespa_accounts')\
        .select('email')\
        .eq('school_id', VESPA_ACADEMY_ID)\
        .eq('account_type', 'student')\
        .execute()
    
    orphaned_emails = {acc['email'] for acc in orphaned.data}
    linked_emails = {std['email'] for std in students.data}
    truly_orphaned = orphaned_emails - linked_emails
    
    if truly_orphaned:
        print(f"⚠️  Found {len(truly_orphaned)} orphaned accounts (in vespa_accounts but not vespa_students)")
        for email in list(truly_orphaned)[:5]:
            print(f"   - {email}")
    else:
        print(f"✅ No orphaned accounts - all accounts properly linked")
    
    # Sample a few students to verify data
    if students.data:
        print(f"\n📋 Sample Student Data:")
        sample = students.data[0]
        print(f"   Email: {sample.get('email')}")
        print(f"   Name: {sample.get('full_name')}")
        print(f"   School: {sample.get('school_name')}")
        print(f"   Year Group: {sample.get('current_year_group')}")
        print(f"   Account ID: {sample.get('account_id')}")


def main():
    """Main migration function"""
    try:
        # Step 1: Migrate students
        migrated, skipped = migrate_vespa_academy_students()
        
        # Step 2: Verify
        verify_migration()
        
        print("\n" + "=" * 80)
        print("✅ VESPA ACADEMY TEST MIGRATION COMPLETE!")
        print("=" * 80)
        print(f"Next steps:")
        print(f"  1. Test activities assignment with VESPA ACADEMY staff")
        print(f"  2. Test student login and activity completion")
        print(f"  3. Verify establishment isolation (students can only see their school's data)")
        print(f"  4. If successful, run full migration for all 127 establishments")
        print()
        
    except Exception as e:
        print(f"\n❌ Migration failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()

