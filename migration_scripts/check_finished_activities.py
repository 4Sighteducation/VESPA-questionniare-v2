"""
Check why finished activities didn't sync for test student
"""

import os
from pathlib import Path
from supabase import create_client
from dotenv import load_dotenv

env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

supabase = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_KEY'))

# Test student's finished activities from field_1380
FINISHED_IDS = ['5fe08034a529d3001b2b5b29', '5ffe0eb05d4ee5001c30fbdb', '5ffe111a1e82a6001e41fe2b']
TEST_EMAIL = '354355@nptcgroup.ac.uk'

print("Checking finished activities for test student...")
print(f"Email: {TEST_EMAIL}")
print(f"Finished activity IDs from field_1380: {FINISHED_IDS}")
print()

# Check if these activities exist in Supabase
print("Checking if activities exist in Supabase activities table:")
for knack_id in FINISHED_IDS:
    result = supabase.table('activities').select('id, name, knack_id').eq('knack_id', knack_id).execute()
    
    if result.data:
        print(f"  OK {knack_id} -> {result.data[0]['name']} (UUID: {result.data[0]['id'][:8]}...)")
    else:
        print(f"  NOT FOUND {knack_id}")

print()

# Check if activity_responses exist for this student
print("Checking activity_responses for this student:")
result = supabase.table('activity_responses').select('*').eq('student_email', TEST_EMAIL).execute()

print(f"Total activity_responses: {len(result.data)}")

if result.data:
    for response in result.data:
        print(f"  - Activity ID: {response.get('activity_id')[:8]}... Status: {response.get('status')}")
else:
    print("  (No activity_responses found)")

print()

# Check if student_activities show completed status
print("Checking student_activities completion status:")
result = supabase.table('student_activities').select('*, activities(name)').eq('student_email', TEST_EMAIL).execute()

if result.data:
    for sa in result.data:
        activity_name = sa.get('activities', {}).get('name', 'Unknown')
        print(f"  - {activity_name}: {sa.get('status')}")

