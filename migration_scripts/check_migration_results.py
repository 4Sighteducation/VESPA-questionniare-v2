"""
Check Migration Results - Step 06
==================================
Verify the student activities migration was successful.
"""

import os
import sys
from pathlib import Path
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables
env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    print("Error: Missing Supabase credentials")
    sys.exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

print("=" * 80)
print("MIGRATION STEP 06 - RESULTS VERIFICATION")
print("=" * 80)
print()

# ============================================================================
# 1. OVERALL COUNTS
# ============================================================================
print("1. OVERALL COUNTS")
print("-" * 80)

try:
    # student_activities count
    result = supabase.table('student_activities').select('*', count='exact').execute()
    print(f"   student_activities: {result.count} records")
    
    # Unique students in student_activities
    result = supabase.table('student_activities').select('student_email').execute()
    unique_students = len(set([r['student_email'] for r in result.data]))
    print(f"   Unique students: {unique_students}")
    
    # activity_responses count
    result = supabase.table('activity_responses').select('*', count='exact').execute()
    print(f"   activity_responses: {result.count} records")
    
    # Unique students with responses
    result = supabase.table('activity_responses').select('student_email').execute()
    unique_with_responses = len(set([r['student_email'] for r in result.data]))
    print(f"   Unique students with responses: {unique_with_responses}")
    
    # vespa_students synced from Knack
    result = supabase.table('vespa_students').select('*', count='exact').is_('last_synced_from_knack', 'not.null').execute()
    print(f"   vespa_students synced from Knack: {result.count}")
    
except Exception as e:
    print(f"   Error: {str(e)}")

print()

# ============================================================================
# 2. STUDENT_ACTIVITIES BY TYPE
# ============================================================================
print("2. STUDENT_ACTIVITIES BY ASSIGNMENT TYPE")
print("-" * 80)

try:
    result = supabase.table('student_activities').select('assigned_by, status').execute()
    
    # Count by assigned_by and status
    counts = {}
    for record in result.data:
        assigned_by = record.get('assigned_by', 'unknown')
        status = record.get('status', 'unknown')
        key = f"{assigned_by} - {status}"
        counts[key] = counts.get(key, 0) + 1
    
    for key, count in sorted(counts.items()):
        print(f"   {key}: {count}")
    
except Exception as e:
    print(f"   Error: {str(e)}")

print()

# ============================================================================
# 3. ACTIVITY_RESPONSES BY STATUS
# ============================================================================
print("3. ACTIVITY_RESPONSES BY STATUS")
print("-" * 80)

try:
    result = supabase.table('activity_responses').select('status, student_email').execute()
    
    status_counts = {}
    for record in result.data:
        status = record.get('status', 'unknown')
        status_counts[status] = status_counts.get(status, 0) + 1
    
    for status, count in sorted(status_counts.items()):
        print(f"   {status}: {count}")
    
except Exception as e:
    print(f"   Error: {str(e)}")

print()

# ============================================================================
# 4. TEST SPECIFIC STUDENT
# ============================================================================
print("4. TEST STUDENT: 354355@nptcgroup.ac.uk")
print("-" * 80)

TEST_EMAIL = '354355@nptcgroup.ac.uk'

try:
    # Check vespa_students
    result = supabase.table('vespa_students').select('*').eq('email', TEST_EMAIL).execute()
    
    if result.data and len(result.data) > 0:
        student = result.data[0]
        print(f"   vespa_student exists: YES")
        print(f"   Total points: {student.get('total_points', 0)}")
        print(f"   Total activities completed: {student.get('total_activities_completed', 0)}")
        print(f"   Last synced: {student.get('last_synced_from_knack', 'Never')}")
        
        prefs = student.get('preferences', {})
        if prefs:
            print(f"   Preferences:")
            print(f"     - completed_first_activity: {prefs.get('completed_first_activity')}")
            print(f"     - notifications_enabled: {prefs.get('notifications_enabled')}")
    else:
        print(f"   vespa_student exists: NO")
    
    print()
    
    # Check student_activities
    result = supabase.table('student_activities').select('*, activities(name, vespa_category)').eq('student_email', TEST_EMAIL).execute()
    
    print(f"   student_activities: {len(result.data)} records")
    if result.data:
        # Group by assigned_by
        by_type = {}
        for record in result.data:
            assigned_by = record.get('assigned_by', 'unknown')
            by_type[assigned_by] = by_type.get(assigned_by, 0) + 1
        
        for assigned_by, count in by_type.items():
            print(f"     - {assigned_by}: {count}")
        
        # Show first 5 activities
        print(f"   Sample activities:")
        for record in result.data[:5]:
            activity = record.get('activities', {})
            print(f"     - {activity.get('name')} ({record.get('assigned_by')}, {record.get('status')})")
    
    print()
    
    # Check activity_responses
    result = supabase.table('activity_responses').select('*, activities(name)').eq('student_email', TEST_EMAIL).execute()
    
    print(f"   activity_responses: {len(result.data)} records")
    if result.data:
        completed = [r for r in result.data if r.get('status') == 'completed']
        print(f"     - completed: {len(completed)}")
        print(f"     - in_progress: {len([r for r in result.data if r.get('status') == 'in_progress'])}")
        
        if completed:
            print(f"   Completed activities:")
            for record in completed[:5]:
                activity = record.get('activities', {})
                print(f"     - {activity.get('name')}")
    
except Exception as e:
    print(f"   Error: {str(e)}")

print()

# ============================================================================
# 5. TOP 10 STUDENTS BY ACTIVITY COUNT
# ============================================================================
print("5. TOP 10 STUDENTS BY ACTIVITY COUNT")
print("-" * 80)

try:
    result = supabase.table('student_activities').select('student_email').execute()
    
    # Count activities per student
    student_counts = {}
    for record in result.data:
        email = record.get('student_email')
        student_counts[email] = student_counts.get(email, 0) + 1
    
    # Sort and show top 10
    top_students = sorted(student_counts.items(), key=lambda x: x[1], reverse=True)[:10]
    
    for email, count in top_students:
        print(f"   {email}: {count} activities")
    
except Exception as e:
    print(f"   Error: {str(e)}")

print()

# ============================================================================
# 6. MOST ASSIGNED ACTIVITIES
# ============================================================================
print("6. TOP 10 MOST ASSIGNED ACTIVITIES")
print("-" * 80)

try:
    result = supabase.table('student_activities').select('activity_id, activities(name, vespa_category)').execute()
    
    # Count assignments per activity
    activity_counts = {}
    activity_names = {}
    
    for record in result.data:
        activity_id = record.get('activity_id')
        activity = record.get('activities', {})
        activity_name = activity.get('name', 'Unknown')
        
        activity_counts[activity_id] = activity_counts.get(activity_id, 0) + 1
        activity_names[activity_id] = activity_name
    
    # Sort and show top 10
    top_activities = sorted(activity_counts.items(), key=lambda x: x[1], reverse=True)[:10]
    
    for activity_id, count in top_activities:
        name = activity_names.get(activity_id, 'Unknown')
        print(f"   {name}: {count} students")
    
except Exception as e:
    print(f"   Error: {str(e)}")

print()

# ============================================================================
# 7. CHECK FOR ISSUES
# ============================================================================
print("7. POTENTIAL ISSUES")
print("-" * 80)

try:
    # Orphaned student_activities (activity doesn't exist)
    result = supabase.rpc('check_orphaned_student_activities').execute() if False else None
    
    # Manual check - activities that don't exist
    all_assignments = supabase.table('student_activities').select('activity_id').execute()
    all_activities = supabase.table('activities').select('id').execute()
    
    activity_ids = set([a['id'] for a in all_activities.data])
    orphaned = 0
    
    for assignment in all_assignments.data:
        if assignment['activity_id'] not in activity_ids:
            orphaned += 1
    
    print(f"   Orphaned student_activities: {orphaned}")
    
    # Check for students without vespa_student record
    result = supabase.table('student_activities').select('student_email').execute()
    activity_emails = set([r['student_email'] for r in result.data])
    
    result = supabase.table('vespa_students').select('email').execute()
    vespa_emails = set([r['email'] for r in result.data])
    
    missing = activity_emails - vespa_emails
    print(f"   Students in student_activities but not in vespa_students: {len(missing)}")
    
    if missing:
        print(f"   Missing students: {list(missing)[:5]}")
    
except Exception as e:
    print(f"   Error: {str(e)}")

print()

# ============================================================================
# SUMMARY
# ============================================================================
print("=" * 80)
print("SUMMARY")
print("=" * 80)
print()
print("Expected for test student (354355@nptcgroup.ac.uk):")
print("  - 10 prescribed activities")
print("  - 3 finished activities")
print()
print("Run the queries above to verify the migration was successful!")
print()

