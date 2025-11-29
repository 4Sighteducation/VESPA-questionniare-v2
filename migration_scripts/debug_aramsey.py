"""
Debug: Why aramsey@vespa.academy has no activities
"""

import os
from pathlib import Path
from supabase import create_client
from dotenv import load_dotenv
import requests

env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

supabase = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_KEY'))

KNACK_APP_ID = os.getenv('KNACK_APP_ID')
KNACK_API_KEY = os.getenv('KNACK_API_KEY')
KNACK_API_BASE = 'https://api.knack.com/v1'

EMAIL = 'aramsey@vespa.academy'

print("=" * 80)
print(f"DEBUGGING: {EMAIL}")
print("=" * 80)
print()

# ============================================================================
# 1. CHECK SUPABASE
# ============================================================================
print("1. SUPABASE - vespa_students")
print("-" * 80)

result = supabase.table('vespa_students').select('*').eq('email', EMAIL).execute()

if result.data:
    student = result.data[0]
    print(f"   EXISTS: Yes")
    print(f"   ID: {student.get('id')}")
    print(f"   Total points: {student.get('total_points')}")
    print(f"   Total completed: {student.get('total_activities_completed')}")
    print(f"   Last synced: {student.get('last_synced_from_knack')}")
else:
    print(f"   EXISTS: No")

print()

# ============================================================================
# 2. CHECK SUPABASE - student_activities
# ============================================================================
print("2. SUPABASE - student_activities")
print("-" * 80)

result = supabase.table('student_activities').select('*, activities(name, vespa_category)').eq('student_email', EMAIL).execute()

print(f"   Count: {len(result.data)}")

if result.data:
    for sa in result.data[:10]:
        activity = sa.get('activities', {})
        print(f"   - {activity.get('name')} ({sa.get('assigned_by')}, {sa.get('status')})")
else:
    print(f"   (No records)")

print()

# ============================================================================
# 3. CHECK SUPABASE - activity_responses
# ============================================================================
print("3. SUPABASE - activity_responses")
print("-" * 80)

result = supabase.table('activity_responses').select('*, activities(name)').eq('student_email', EMAIL).execute()

print(f"   Count: {len(result.data)}")

if result.data:
    for ar in result.data[:10]:
        activity = ar.get('activities', {})
        print(f"   - {activity.get('name')} ({ar.get('status')}, {ar.get('selected_via')})")
        if ar.get('knack_id'):
            print(f"     Knack ID: {ar.get('knack_id')}")
else:
    print(f"   (No records)")

print()

# ============================================================================
# 4. CHECK KNACK - Object_6 (Student Record)
# ============================================================================
print("4. KNACK - Object_6 (Student Record)")
print("-" * 80)

headers = {
    'X-Knack-Application-Id': KNACK_APP_ID,
    'X-Knack-REST-API-Key': KNACK_API_KEY
}

# Search for student
found = False
for page in range(1, 10):
    response = requests.get(
        f"{KNACK_API_BASE}/objects/object_6/records",
        headers=headers,
        params={'rows_per_page': 100, 'page': page}
    )
    
    if response.status_code != 200:
        print(f"   Error fetching page {page}: {response.status_code}")
        break
    
    data = response.json()
    records = data.get('records', [])
    
    for record in records:
        email_field = record.get('field_91') or record.get('field_91_raw')
        
        # Handle various formats
        if isinstance(email_field, dict):
            email_field = email_field.get('email')
        
        if isinstance(email_field, str) and 'mailto:' in email_field:
            import re
            match = re.search(r'mailto:([^"]+)', email_field)
            if match:
                email_field = match.group(1)
        
        if email_field == EMAIL:
            found = True
            print(f"   EXISTS: Yes")
            print(f"   Record ID: {record.get('id')}")
            print()
            
            # Check field_1683 (Prescribed Activities)
            field_1683 = record.get('field_1683', '')
            field_1683_raw = record.get('field_1683_raw', [])
            
            print(f"   field_1683 (Prescribed Activities):")
            if isinstance(field_1683_raw, list) and field_1683_raw:
                print(f"     Count: {len(field_1683_raw)}")
                for item in field_1683_raw[:5]:
                    print(f"     - {item.get('identifier')} (ID: {item.get('id')})")
            else:
                print(f"     (Empty or not available)")
            
            print()
            
            # Check field_1380 (Finished Activities)
            field_1380 = record.get('field_1380', '')
            print(f"   field_1380 (Finished Activities):")
            if field_1380:
                ids = field_1380.split(',')
                print(f"     Count: {len(ids)}")
                print(f"     IDs: {ids}")
            else:
                print(f"     (Empty)")
            
            print()
            
            # Check field_3580, 3581
            field_3580 = record.get('field_3580', '')
            field_3581 = record.get('field_3581', '')
            
            print(f"   field_3580 (Student-Added): {field_3580 or '(Empty)'}")
            print(f"   field_3581 (Staff-Added): {field_3581 or '(Empty)'}")
            
            break
    
    if found:
        break
    
    if page >= data.get('total_pages', 1):
        break

if not found:
    print(f"   EXISTS: No (not found in first {page * 100} records)")

print()

# ============================================================================
# SUMMARY
# ============================================================================
print("=" * 80)
print("DIAGNOSIS")
print("=" * 80)
print()
print("If student has activities in Knack but NOT in Supabase:")
print("  -> They were NOT included in migration (might be new student)")
print("  -> Run migration again OR manually sync this student")
print()
print("If student has NO activities in Knack:")
print("  -> They haven't been assigned activities yet")
print("  -> Check if they're using a different email")
print()
print("If student has activities in activity_responses but not student_activities:")
print("  -> Historical data exists but not current assignments")
print("  -> They completed activities but don't have new ones assigned")
print()

