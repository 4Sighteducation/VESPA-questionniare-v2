"""
Verify migration completion - Check counts and data integrity
"""
import os
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables from DASHBOARD folder
env_path = os.path.join(
    os.path.dirname(__file__),
    '..', '..', 'DASHBOARD', 'DASHBOARD', '.env'
)
load_dotenv(env_path)

# Initialize Supabase
supabase: Client = create_client(
    os.environ.get("SUPABASE_URL"),
    os.environ.get("SUPABASE_SERVICE_KEY")
)

def verify_migration():
    """Verify migration completion"""
    
    print("🔍 Verifying Migration Completion")
    print("="*60)
    
    # Check activities
    activities_result = supabase.table("activities").select("id", count="exact").execute()
    activities_count = activities_result.count if hasattr(activities_result, 'count') else len(activities_result.data)
    print(f"✅ Activities: {activities_count} (Expected: 75)")
    
    # Check questions
    questions_result = supabase.table("activity_questions").select("id", count="exact").execute()
    questions_count = questions_result.count if hasattr(questions_result, 'count') else len(questions_result.data)
    print(f"✅ Questions: {questions_count} (Expected: ~1000-1016)")
    
    # Check questions by activity
    questions_by_activity = supabase.table("activity_questions").select("activity_id").execute()
    activity_question_counts = {}
    for q in questions_by_activity.data:
        activity_id = q["activity_id"]
        activity_question_counts[activity_id] = activity_question_counts.get(activity_id, 0) + 1
    
    print(f"\n📊 Questions per activity:")
    print(f"   Activities with questions: {len(activity_question_counts)}")
    print(f"   Average questions per activity: {questions_count / len(activity_question_counts) if activity_question_counts else 0:.1f}")
    
    # Check for activities with no questions
    all_activities = supabase.table("activities").select("id, name").execute()
    activities_without_questions = []
    for activity in all_activities.data:
        if activity["id"] not in activity_question_counts:
            activities_without_questions.append(activity["name"])
    
    if activities_without_questions:
        print(f"\n⚠️  Activities with no questions ({len(activities_without_questions)}):")
        for name in activities_without_questions[:10]:
            print(f"   - {name}")
        if len(activities_without_questions) > 10:
            print(f"   ... and {len(activities_without_questions) - 10} more")
    else:
        print(f"\n✅ All activities have questions!")
    
    # Check for duplicate display_order issues
    print(f"\n🔍 Checking for duplicate display_order issues...")
    duplicates_found = False
    for activity_id in activity_question_counts.keys():
        questions = supabase.table("activity_questions").select("display_order").eq("activity_id", activity_id).execute()
        orders = [q["display_order"] for q in questions.data]
        if len(orders) != len(set(orders)):
            duplicates_found = True
            print(f"   ⚠️  Activity {activity_id} has duplicate display_order values")
    
    if not duplicates_found:
        print(f"   ✅ No duplicate display_order issues found!")
    
    print("\n" + "="*60)
    print("📊 VERIFICATION SUMMARY")
    print("="*60)
    print(f"✅ Activities migrated: {activities_count}/75")
    print(f"✅ Questions migrated: {questions_count}")
    print(f"✅ Activities with questions: {len(activity_question_counts)}/75")
    
    if activities_count == 75 and questions_count >= 1000:
        print("\n🎉 Migration verification PASSED!")
        return True
    else:
        print("\n⚠️  Migration verification has issues - review above")
        return False


if __name__ == "__main__":
    verify_migration()


