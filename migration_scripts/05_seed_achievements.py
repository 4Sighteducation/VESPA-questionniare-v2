"""
VESPA Activities V3 - Migration Script 5
Seeds achievement definitions for the gamification system
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

# Achievement definitions
ACHIEVEMENT_DEFINITIONS = [
    # Milestone achievements
    {
        "achievement_type": "first_activity",
        "name": "First Steps",
        "description": "Completed your first VESPA activity",
        "icon_emoji": "🚶",
        "points_value": 10,
        "criteria": {"type": "activities_completed", "count": 1},
        "display_order": 1
    },
    {
        "achievement_type": "five_complete",
        "name": "Rising Star",
        "description": "Completed 5 activities",
        "icon_emoji": "⭐",
        "points_value": 25,
        "criteria": {"type": "activities_completed", "count": 5},
        "display_order": 2
    },
    {
        "achievement_type": "ten_complete",
        "name": "Dedicated Learner",
        "description": "Completed 10 activities",
        "icon_emoji": "📚",
        "points_value": 50,
        "criteria": {"type": "activities_completed", "count": 10},
        "display_order": 3
    },
    {
        "achievement_type": "fifteen_complete",
        "name": "Committed Student",
        "description": "Completed 15 activities",
        "icon_emoji": "🎯",
        "points_value": 75,
        "criteria": {"type": "activities_completed", "count": 15},
        "display_order": 4
    },
    {
        "achievement_type": "twenty_complete",
        "name": "VESPA Champion",
        "description": "Completed 20 activities",
        "icon_emoji": "🏆",
        "points_value": 100,
        "criteria": {"type": "activities_completed", "count": 20},
        "display_order": 5
    },
    
    # Category mastery achievements
    {
        "achievement_type": "vision_master",
        "name": "Vision Master",
        "description": "Completed 80% of Vision activities for your level",
        "icon_emoji": "🔭",
        "points_value": 75,
        "criteria": {"type": "category_master", "category": "Vision", "percentage": 80},
        "display_order": 10
    },
    {
        "achievement_type": "effort_master",
        "name": "Effort Master",
        "description": "Completed 80% of Effort activities for your level",
        "icon_emoji": "💪",
        "points_value": 75,
        "criteria": {"type": "category_master", "category": "Effort", "percentage": 80},
        "display_order": 11
    },
    {
        "achievement_type": "systems_master",
        "name": "Systems Master",
        "description": "Completed 80% of Systems activities for your level",
        "icon_emoji": "⚙️",
        "points_value": 75,
        "criteria": {"type": "category_master", "category": "Systems", "percentage": 80},
        "display_order": 12
    },
    {
        "achievement_type": "practice_master",
        "name": "Practice Master",
        "description": "Completed 80% of Practice activities for your level",
        "icon_emoji": "📝",
        "points_value": 75,
        "criteria": {"type": "category_master", "category": "Practice", "percentage": 80},
        "display_order": 13
    },
    {
        "achievement_type": "attitude_master",
        "name": "Attitude Master",
        "description": "Completed 80% of Attitude activities for your level",
        "icon_emoji": "😊",
        "points_value": 75,
        "criteria": {"type": "category_master", "category": "Attitude", "percentage": 80},
        "display_order": 14
    },
    
    # Streak achievements
    {
        "achievement_type": "three_day_streak",
        "name": "Getting Started",
        "description": "Worked on activities 3 days in a row",
        "icon_emoji": "🔥",
        "points_value": 20,
        "criteria": {"type": "streak", "days": 3},
        "display_order": 20
    },
    {
        "achievement_type": "week_streak",
        "name": "Weekly Warrior",
        "description": "Worked on activities 7 days in a row",
        "icon_emoji": "🔥",
        "points_value": 50,
        "criteria": {"type": "streak", "days": 7},
        "display_order": 21
    },
    {
        "achievement_type": "two_week_streak",
        "name": "Consistency King",
        "description": "Worked on activities 14 days in a row",
        "icon_emoji": "👑",
        "points_value": 100,
        "criteria": {"type": "streak", "days": 14},
        "display_order": 22
    },
    {
        "achievement_type": "month_streak",
        "name": "Unstoppable",
        "description": "Worked on activities 30 days in a row",
        "icon_emoji": "🚀",
        "points_value": 200,
        "criteria": {"type": "streak", "days": 30},
        "display_order": 23
    },
    
    # Quality achievements
    {
        "achievement_type": "thoughtful_reflection",
        "name": "Thoughtful Scholar",
        "description": "Wrote a reflection with 500+ words",
        "icon_emoji": "💭",
        "points_value": 25,
        "criteria": {"type": "word_count", "min": 500},
        "display_order": 30
    },
    {
        "achievement_type": "detailed_response",
        "name": "Detail Oriented",
        "description": "Wrote a reflection with 1000+ words",
        "icon_emoji": "📖",
        "points_value": 50,
        "criteria": {"type": "word_count", "min": 1000},
        "display_order": 31
    },
    
    # Speed achievements
    {
        "achievement_type": "quick_completion",
        "name": "Efficient Worker",
        "description": "Completed an activity in under the recommended time",
        "icon_emoji": "⚡",
        "points_value": 20,
        "criteria": {"type": "time_bonus", "under_recommended": True},
        "display_order": 40
    },
    
    # Category completion achievements
    {
        "achievement_type": "category_complete_vision",
        "name": "Vision Complete",
        "description": "Completed ALL Vision activities for your level",
        "icon_emoji": "🌟",
        "points_value": 150,
        "criteria": {"type": "category_complete", "category": "Vision"},
        "display_order": 50
    },
    {
        "achievement_type": "category_complete_effort",
        "name": "Effort Complete",
        "description": "Completed ALL Effort activities for your level",
        "icon_emoji": "💯",
        "points_value": 150,
        "criteria": {"type": "category_complete", "category": "Effort"},
        "display_order": 51
    },
    {
        "achievement_type": "category_complete_systems",
        "name": "Systems Complete",
        "description": "Completed ALL Systems activities for your level",
        "icon_emoji": "✅",
        "points_value": 150,
        "criteria": {"type": "category_complete", "category": "Systems"},
        "display_order": 52
    },
    {
        "achievement_type": "category_complete_practice",
        "name": "Practice Complete",
        "description": "Completed ALL Practice activities for your level",
        "icon_emoji": "🎓",
        "points_value": 150,
        "criteria": {"type": "category_complete", "category": "Practice"},
        "display_order": 53
    },
    {
        "achievement_type": "category_complete_attitude",
        "name": "Attitude Complete",
        "description": "Completed ALL Attitude activities for your level",
        "icon_emoji": "😎",
        "points_value": 150,
        "criteria": {"type": "category_complete", "category": "Attitude"},
        "display_order": 54
    },
    
    # Ultimate achievement
    {
        "achievement_type": "vespa_master",
        "name": "VESPA Master",
        "description": "Completed ALL activities across all categories",
        "icon_emoji": "🏅",
        "points_value": 500,
        "criteria": {"type": "all_complete"},
        "display_order": 100
    }
]

def seed_achievements():
    """Seed achievement definitions"""
    
    print(f"📊 Seeding {len(ACHIEVEMENT_DEFINITIONS)} achievement definitions...")
    
    seeded_count = 0
    errors = []
    
    for achievement_def in ACHIEVEMENT_DEFINITIONS:
        try:
            # Upsert to handle re-runs
            supabase.table("achievement_definitions").upsert(
                achievement_def,
                on_conflict="achievement_type"
            ).execute()
            
            seeded_count += 1
            print(f"✅ Seeded: {achievement_def['name']} ({achievement_def['points_value']} points)")
            
        except Exception as e:
            errors.append({
                "achievement": achievement_def["name"],
                "error": str(e)
            })
            print(f"❌ Error seeding '{achievement_def['name']}': {e}")
    
    # Print summary
    print("\n" + "="*60)
    print(f"📊 SEEDING SUMMARY")
    print("="*60)
    print(f"Total achievements: {len(ACHIEVEMENT_DEFINITIONS)}")
    print(f"Successfully seeded: {seeded_count}")
    print(f"Errors: {len(errors)}")
    
    if errors:
        print("\n❌ Failed seeding:")
        for err in errors:
            print(f"  - {err['achievement']}: {err['error']}")
    else:
        print("\n✅ All achievement definitions seeded successfully!")
    
    return seeded_count, errors


if __name__ == "__main__":
    print("🚀 Starting VESPA Activities Migration - Step 5: Achievement Definitions")
    print("="*60)
    
    seeded, errors = seed_achievements()
    
    if errors:
        print("\n⚠️  Seeding completed with errors. Please review above.")
        exit(1)
    else:
        print("\n🎉 Migration Step 5 completed successfully!")
        print("\n✅ ALL MIGRATION STEPS COMPLETE!")
        print("➡️  Next: Build Vue 3 apps")
        exit(0)

