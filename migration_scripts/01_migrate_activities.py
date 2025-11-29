"""
VESPA Activities V3 - Migration Script 1
Migrates 75 activities from structured_activities_with_thresholds.json to Supabase
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

def migrate_activities():
    """Migrate activities from JSON to Supabase"""
    
    # Load structured activities JSON
    json_path = os.path.join(
        os.path.dirname(__file__),
        '..',
        '..',
        'vespa-activities-v2',
        'shared',
        'utils',
        'structured_activities_with_thresholds.json'
    )
    
    print(f"📂 Loading activities from: {json_path}")
    
    with open(json_path, 'r', encoding='utf-8') as f:
        activities_data = json.load(f)
    
    print(f"📊 Found {len(activities_data)} activities to migrate")
    
    migrated_count = 0
    errors = []
    
    for activity in activities_data:
        try:
            # Parse content sections
            content = {
                "do": activity["sections"].get("do", {}),
                "think": activity["sections"].get("think", {}),
                "learn": activity["sections"].get("learn", {}),
                "reflect": activity["sections"].get("reflect", {})
            }
            
            # Create slug from name
            slug = activity["activity_name"].lower().replace(" ", "-").replace("'", "")
            
            # Prepare data for Supabase
            data = {
                "knack_id": activity["id"],
                "name": activity["activity_name"],
                "slug": slug,
                "vespa_category": activity["category"]["name"],
                "level": activity["level"],
                "difficulty": activity.get("difficulty", 0),
                "time_minutes": activity.get("time_minutes"),
                "score_threshold_min": activity.get("show_if_score_more_than"),
                "score_threshold_max": activity.get("show_if_score_less_than"),
                "content": content,
                "do_section_html": activity["raw_fields"].get("field_1289_raw", ""),
                "think_section_html": activity["raw_fields"].get("field_1288_raw", ""),
                "learn_section_html": activity["raw_fields"].get("field_1293_raw", ""),
                "reflect_section_html": activity["raw_fields"].get("field_1313_raw", ""),
                "color": activity.get("colour", ""),
                "display_order": activity.get("display_order"),
                "is_active": activity.get("active", True),
                "problem_mappings": []  # Will be populated in step 3
            }
            
            # Insert into Supabase
            result = supabase.table("activities").insert(data).execute()
            migrated_count += 1
            print(f"✅ [{migrated_count}/{len(activities_data)}] Migrated: {activity['activity_name']}")
            
        except Exception as e:
            error_msg = str(e)
            errors.append({
                "activity": activity["activity_name"],
                "error": error_msg
            })
            print(f"❌ Error migrating '{activity['activity_name']}': {error_msg}")
    
    # Print summary
    print("\n" + "="*60)
    print(f"📊 MIGRATION SUMMARY")
    print("="*60)
    print(f"Total activities: {len(activities_data)}")
    print(f"Successfully migrated: {migrated_count}")
    print(f"Errors: {len(errors)}")
    
    if errors:
        print("\n❌ Failed migrations:")
        for err in errors:
            print(f"  - {err['activity']}")
            print(f"    Error: {err['error']}")
    else:
        print("\n✅ All activities migrated successfully!")
    
    return migrated_count, errors


if __name__ == "__main__":
    print("🚀 Starting VESPA Activities Migration - Step 1: Activities")
    print("="*60)
    
    migrated, errors = migrate_activities()
    
    if errors:
        print("\n⚠️  Migration completed with errors. Please review above.")
        exit(1)
    else:
        print("\n🎉 Migration Step 1 completed successfully!")
        print("➡️  Next: Run 02_migrate_questions.py")
        exit(0)

