"""
VESPA Activities V3 - Migration Script 3
Updates activity.problem_mappings array from vespa-problem-activity-mappings1a.json
"""
import json
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

def update_problem_mappings():
    """Update problem_mappings array for each activity"""
    
    # Load problem mappings JSON
    json_path = os.path.join(
        os.path.dirname(__file__),
        '..',
        '..',
        'vespa-activities-v2',
        'shared',
        'vespa-problem-activity-mappings1a.json'
    )
    
    print(f"📂 Loading problem mappings from: {json_path}")
    
    with open(json_path, 'r', encoding='utf-8') as f:
        mappings_data = json.load(f)
    
    problem_mappings = mappings_data.get("problemMappings", {})
    
    # Build activity_id → problem_ids mapping
    activity_to_problems = {}
    
    for category, problems in problem_mappings.items():
        for problem in problems:
            problem_id = problem["id"]
            activity_ids = problem.get("activityIds", [])
            
            for activity_knack_id in activity_ids:
                if activity_knack_id not in activity_to_problems:
                    activity_to_problems[activity_knack_id] = []
                activity_to_problems[activity_knack_id].append(problem_id)
    
    print(f"📊 Found {len(activity_to_problems)} activities with problem mappings")
    
    # Fetch all activities from Supabase
    activities_result = supabase.table("activities").select("id, knack_id, name").execute()
    
    updated_count = 0
    errors = []
    
    for activity in activities_result.data:
        knack_id = activity["knack_id"]
        
        if knack_id in activity_to_problems:
            problem_ids = activity_to_problems[knack_id]
            
            try:
                # Update problem_mappings array
                supabase.table("activities").update({
                    "problem_mappings": problem_ids
                }).eq("id", activity["id"]).execute()
                
                updated_count += 1
                print(f"✅ Updated: {activity['name']} ({len(problem_ids)} problems)")
                
            except Exception as e:
                errors.append({
                    "activity": activity["name"],
                    "error": str(e)
                })
                print(f"❌ Error updating '{activity['name']}': {e}")
    
    # Print summary
    print("\n" + "="*60)
    print(f"📊 MIGRATION SUMMARY")
    print("="*60)
    print(f"Total activities in Supabase: {len(activities_result.data)}")
    print(f"Activities with problem mappings: {len(activity_to_problems)}")
    print(f"Successfully updated: {updated_count}")
    print(f"Errors: {len(errors)}")
    
    if errors:
        print("\n❌ Failed updates:")
        for err in errors:
            print(f"  - {err['activity']}: {err['error']}")
    else:
        print("\n✅ All problem mappings updated successfully!")
    
    return updated_count, errors


if __name__ == "__main__":
    print("🚀 Starting VESPA Activities Migration - Step 3: Problem Mappings")
    print("="*60)
    
    updated, errors = update_problem_mappings()
    
    if errors:
        print("\n⚠️  Migration completed with errors. Please review above.")
        exit(1)
    else:
        print("\n🎉 Migration Step 3 completed successfully!")
        print("➡️  Next: Run 04_migrate_historical_responses.py")
        exit(0)

