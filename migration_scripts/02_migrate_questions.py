"""
VESPA Activities V3 - Migration Script 2
Migrates 1,573 activity questions from CSV to Supabase
"""
import csv
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

def migrate_questions():
    """Migrate activity questions from CSV to Supabase"""
    
    # First, fetch all activities to create name→UUID mapping
    print("📂 Fetching activities from Supabase...")
    activities_result = supabase.table("activities").select("id, name, knack_id").execute()
    
    activity_map = {a["name"]: a["id"] for a in activities_result.data}
    print(f"✅ Loaded {len(activity_map)} activities for mapping")
    
    # Load CSV
    csv_path = os.path.join(
        os.path.dirname(__file__),
        '..',
        'activityquestion.csv'
    )
    
    print(f"📂 Loading questions from: {csv_path}")
    
    migrated_count = 0
    skipped_count = 0
    errors = []
    
    with open(csv_path, 'r', encoding='utf-8-sig') as f:  # utf-8-sig handles BOM
        reader = csv.DictReader(f)
        
        # Debug: Print column names to verify
        if reader.fieldnames:
            print(f"📋 CSV Columns detected: {list(reader.fieldnames)}")
        
        total_rows = 0
        
        for row in reader:
            total_rows += 1
            
            try:
                # Normalize column names (strip whitespace)
                row_normalized = {k.strip(): v for k, v in row.items()}
                
                # Get activity name
                activity_name = row_normalized.get("Activity", "").strip()
                
                # Skip if no activity name
                if not activity_name:
                    skipped_count += 1
                    continue
                
                # Skip if inactive
                active_value = row_normalized.get("Active", "").strip()
                if active_value != "True":
                    skipped_count += 1
                    continue
                
                # Get activity UUID
                if activity_name not in activity_map:
                    print(f"⚠️  Activity not found in Supabase: '{activity_name}' (skipping)")
                    skipped_count += 1
                    continue
                
                activity_id = activity_map[activity_name]
                
                # Parse dropdown/checkbox options
                options_str = row_normalized.get("Dropdown/Checkbox options", "").strip()
                dropdown_options = []
                if options_str:
                    dropdown_options = [opt.strip() for opt in options_str.split(",") if opt.strip()]
                
                # Parse order (handle empty values)
                order_str = row_normalized.get("Order", "").strip()
                try:
                    base_display_order = int(order_str) if order_str else 0
                except (ValueError, TypeError):
                    base_display_order = 0
                
                # Check for duplicate display_order and auto-increment if needed
                display_order = base_display_order
                max_attempts = 1000  # Safety limit
                attempt = 0
                
                while attempt < max_attempts:
                    # Check if this order already exists for this activity
                    existing = supabase.table("activity_questions").select("id").eq("activity_id", activity_id).eq("display_order", display_order).execute()
                    
                    if not existing.data or len(existing.data) == 0:
                        # Order is free, use it
                        break
                    
                    # Order is taken, increment
                    display_order += 1
                    attempt += 1
                
                if attempt > 0:
                    print(f"  ⚠️  Duplicate order detected: '{activity_name}' - '{row_normalized.get('Question Title', '')[:50]}' - adjusted order from {base_display_order} to {display_order}")
                
                # Prepare data
                data = {
                    "activity_id": activity_id,
                    "question_title": row_normalized.get("Question Title", "").strip(),
                    "text_above_question": row_normalized.get("Text Above Question", "").strip(),
                    "question_type": row_normalized.get("Type", "").strip(),
                    "dropdown_options": dropdown_options,
                    "display_order": display_order,
                    "is_active": active_value == "True",
                    "answer_required": row_normalized.get("Answer Required?", "").strip() == "Yes",
                    "show_in_final_questions": row_normalized.get("Show in Final Questions Section", "").strip() == "Yes"
                }
                
                # Insert into Supabase
                supabase.table("activity_questions").insert(data).execute()
                migrated_count += 1
                
                if migrated_count % 100 == 0:
                    print(f"📝 Progress: {migrated_count} questions migrated...")
                    
            except Exception as e:
                error_msg = str(e)
                errors.append({
                    "row_number": total_rows,
                    "activity": row.get("Activity", "Unknown"),
                    "question": row.get("Question Title", "Unknown"),
                    "error": error_msg
                })
    
    # Print summary
    print("\n" + "="*60)
    print(f"📊 MIGRATION SUMMARY")
    print("="*60)
    print(f"Total rows processed: {total_rows}")
    print(f"Successfully migrated: {migrated_count}")
    print(f"Skipped (no activity/inactive): {skipped_count}")
    print(f"Errors: {len(errors)}")
    
    if errors:
        print("\n❌ Failed migrations (first 10):")
        for err in errors[:10]:
            print(f"  - Row {err['row_number']}: {err['activity']} - {err['question']}")
            print(f"    Error: {err['error']}")
        
        if len(errors) > 10:
            print(f"  ... and {len(errors) - 10} more errors")
    else:
        print("\n✅ All questions migrated successfully!")
    
    return migrated_count, errors


if __name__ == "__main__":
    print("🚀 Starting VESPA Activities Migration - Step 2: Questions")
    print("="*60)
    
    migrated, errors = migrate_questions()
    
    if errors:
        print("\n⚠️  Migration completed with errors. Please review above.")
        exit(1)
    else:
        print("\n🎉 Migration Step 2 completed successfully!")
        print("➡️  Next: Run 03_update_problem_mappings.py")
        exit(0)

