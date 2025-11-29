"""
Check if Object_46 (Activity Answers) were migrated correctly
"""

import os
from pathlib import Path
from supabase import create_client
from dotenv import load_dotenv

env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

supabase = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_KEY'))

EMAIL = 'aramsey@vespa.academy'

print("=" * 80)
print("CHECKING OBJECT_46 MIGRATION (activity_responses)")
print("=" * 80)
print()

# ============================================================================
# 1. Overall migration stats
# ============================================================================
print("1. OVERALL STATS")
print("-" * 80)

result = supabase.table('activity_responses').select('*', count='exact').execute()
print(f"   Total activity_responses: {result.count}")

# Count migrated vs new (skip complex filter for now)
result_all = supabase.table('activity_responses').select('knack_id').execute()
migrated_count = sum(1 for r in result_all.data if r.get('knack_id'))
new_count = sum(1 for r in result_all.data if not r.get('knack_id'))

print(f"   Migrated from Knack (has knack_id): {migrated_count}")
print(f"   Created by new app (no knack_id): {new_count}")

print()

# ============================================================================
# 2. Check aramsey's activity_responses
# ============================================================================
print(f"2. ACTIVITY_RESPONSES FOR {EMAIL}")
print("-" * 80)

result = supabase.table('activity_responses').select('*').eq('student_email', EMAIL).execute()

print(f"   Total responses: {len(result.data)}")

if result.data:
    for ar in result.data:
        print(f"\n   Response ID: {ar.get('id')}")
        print(f"   Activity ID: {ar.get('activity_id')}")
        print(f"   Status: {ar.get('status')}")
        print(f"   Started: {ar.get('started_at')}")
        print(f"   Completed: {ar.get('completed_at')}")
        print(f"   Knack ID: {ar.get('knack_id', '(none - created by new app)')}")
        print(f"   Responses JSON keys: {list(ar.get('responses', {}).keys())}")
        print(f"   Responses text length: {len(ar.get('responses_text') or '')}")
        print(f"   Time spent: {ar.get('time_spent_minutes')} min")
        print(f"   Word count: {ar.get('word_count')}")

print()

# ============================================================================
# 3. Check if responses have actual question data
# ============================================================================
print("3. SAMPLE RESPONSE DATA")
print("-" * 80)

if result.data and len(result.data) > 0:
    sample = result.data[0]
    
    print(f"   Response ID: {sample.get('id')}")
    print(f"   Responses object: {sample.get('responses')}")
    print(f"   Responses text: {(sample.get('responses_text') or '')[:200]}")
else:
    print("   (No responses to sample)")

print()

# ============================================================================
# 4. For each of aramsey's 3 activities, check if responses exist
# ============================================================================
print("4. MATCH ACTIVITIES TO RESPONSES")
print("-" * 80)

# Get the 3 activities
activities = [
    {'name': "What's Stopping You", 'id': '57b5b06a-1e7f-4f42-a1fc-6415b7aa2226'},
    {'name': 'Success Leaves Clues', 'id': '716e1b16-633c-4fee-8fd3-33fcf4c743e1'},
    {'name': 'Rule of 3', 'id': '25d59761-0ce1-4227-be4d-fc8188a30f00'}
]

for activity in activities:
    print(f"\n   Activity: {activity['name']}")
    
    # Check if response exists
    result = supabase.table('activity_responses').select('*').eq('student_email', EMAIL).eq('activity_id', activity['id']).execute()
    
    if result.data:
        ar = result.data[0]
        print(f"     HAS RESPONSE: Yes")
        print(f"     Status: {ar.get('status')}")
        print(f"     Has question answers: {len(ar.get('responses', {}))} questions")
        print(f"     Has text: {len(ar.get('responses_text') or '')} chars")
    else:
        print(f"     HAS RESPONSE: No")

print()

# ============================================================================
# 5. Check if activity questions exist
# ============================================================================
print("5. CHECK ACTIVITY QUESTIONS")
print("-" * 80)

for activity in activities[:1]:  # Just check first one
    print(f"\n   Activity: {activity['name']}")
    
    result = supabase.table('activity_questions').select('id, question_title, question_type', count='exact').eq('activity_id', activity['id']).eq('is_active', True).execute()
    
    print(f"     Questions available: {result.count}")
    
    if result.data and len(result.data) > 0:
        for q in result.data[:3]:
            print(f"       - {q.get('question_title')} ({q.get('question_type')})")

print()
print("=" * 80)
print("SUMMARY")
print("=" * 80)
print()
print("If responses have empty 'responses' JSON:")
print("  -> Student hasn't answered questions yet (newly started)")
print("  -> This is normal for in_progress activities")
print()
print("If responses have data in 'responses' JSON:")
print("  -> Questions answered and saved")
print("  -> Frontend should display them when reopening activity")
print()

