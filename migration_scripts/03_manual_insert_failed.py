"""
Manually insert failed questions from failed_questions.csv
Handles duplicates and timeouts with retry logic
"""
import csv
import os
import time
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

def manual_insert_failed():
    """Manually insert failed questions with retry logic"""
    
    # Fetch all activities
    print("📂 Fetching activities from Supabase...")
    activities_result = supabase.table("activities").select("id, name").execute()
    activity_map = {a["name"]: a["id"] for a in activities_result.data}
    print(f"✅ Loaded {len(activity_map)} activities")
    
    # Load failed questions CSV
    failed_csv_path = os.path.join(
        os.path.dirname(__file__),
        'failed_questions.csv'
    )
    
    if not os.path.exists(failed_csv_path):
        print(f"❌ File not found: {failed_csv_path}")
        print("💡 Run 02_extract_failed_questions.py first")
        return
    
    print(f"📂 Loading failed questions from: {failed_csv_path}")
    
    inserted_count = 0
    skipped_count = 0
    errors = []
    
    with open(failed_csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        for row in reader:
            reason = row.get("reason", "").strip()
            
            # Skip records with "No activity name" - can't migrate these
            if "No activity name" in reason:
                skipped_count += 1
                print(f"⏭️  Skipping row {row.get('row_number')}: {reason}")
                continue
            
            # Skip inactive records
            if "Inactive" in reason:
                skipped_count += 1
                print(f"⏭️  Skipping row {row.get('row_number')}: {reason}")
                continue
            
            activity_name = row.get("Activity", "").strip()
            question_title = row.get("Question Title", "").strip()
            
            if not activity_name or activity_name not in activity_map:
                skipped_count += 1
                print(f"⏭️  Skipping row {row.get('row_number')}: Activity '{activity_name}' not found")
                continue
            
            activity_id = activity_map[activity_name]
            
            # Check if already migrated
            existing = supabase.table("activity_questions").select("id").eq("activity_id", activity_id).eq("question_title", question_title).execute()
            if existing.data:
                skipped_count += 1
                print(f"✅ Already migrated: {activity_name} - {question_title[:50]}")
                continue
            
            try:
                # Parse dropdown options
                options_str = row.get("Dropdown/Checkbox options", "").strip()
                dropdown_options = []
                if options_str:
                    dropdown_options = [opt.strip() for opt in options_str.split(",") if opt.strip()]
                
                # Parse order
                order_str = row.get("Order", "").strip()
                try:
                    base_display_order = int(order_str) if order_str else 0
                except (ValueError, TypeError):
                    base_display_order = 0
                
                # Find available display_order (handle duplicates)
                display_order = base_display_order
                max_attempts = 1000
                attempt = 0
                
                while attempt < max_attempts:
                    existing_order = supabase.table("activity_questions").select("id").eq("activity_id", activity_id).eq("display_order", display_order).execute()
                    
                    if not existing_order.data or len(existing_order.data) == 0:
                        break
                    
                    display_order += 1
                    attempt += 1
                
                if attempt > 0:
                    print(f"  ⚠️  Adjusted order from {base_display_order} to {display_order}")
                
                # Prepare data
                data = {
                    "activity_id": activity_id,
                    "question_title": question_title,
                    "text_above_question": row.get("Text Above Question", "").strip(),
                    "question_type": row.get("Type", "").strip(),
                    "dropdown_options": dropdown_options,
                    "display_order": display_order,
                    "is_active": row.get("Active", "").strip() == "True",
                    "answer_required": row.get("Answer Required?", "").strip() == "Yes",
                    "show_in_final_questions": row.get("Show in Final Questions Section", "").strip() == "Yes"
                }
                
                # Insert with retry logic for timeouts
                max_retries = 3
                retry_count = 0
                success = False
                
                while retry_count < max_retries and not success:
                    try:
                        supabase.table("activity_questions").insert(data).execute()
                        success = True
                        inserted_count += 1
                        print(f"✅ [{inserted_count}] Inserted: {activity_name} - {question_title[:50]}")
                    except Exception as e:
                        error_msg = str(e)
                        if "timeout" in error_msg.lower() or "timed out" in error_msg.lower():
                            retry_count += 1
                            if retry_count < max_retries:
                                wait_time = retry_count * 2  # Exponential backoff
                                print(f"  ⏳ Timeout, retrying in {wait_time}s... (attempt {retry_count + 1}/{max_retries})")
                                time.sleep(wait_time)
                            else:
                                errors.append({
                                    "row": row.get("row_number"),
                                    "activity": activity_name,
                                    "question": question_title,
                                    "error": f"Timeout after {max_retries} retries"
                                })
                                print(f"❌ Failed after {max_retries} retries: {activity_name} - {question_title[:50]}")
                        else:
                            errors.append({
                                "row": row.get("row_number"),
                                "activity": activity_name,
                                "question": question_title,
                                "error": error_msg
                            })
                            print(f"❌ Error: {activity_name} - {question_title[:50]}")
                            print(f"   {error_msg}")
                            break
                
            except Exception as e:
                errors.append({
                    "row": row.get("row_number"),
                    "activity": activity_name,
                    "question": question_title,
                    "error": str(e)
                })
                print(f"❌ Exception: {activity_name} - {question_title[:50]}")
                print(f"   {str(e)}")
    
    # Print summary
    print("\n" + "="*60)
    print("📊 MANUAL INSERT SUMMARY")
    print("="*60)
    print(f"Successfully inserted: {inserted_count}")
    print(f"Skipped (already migrated/inactive/no activity): {skipped_count}")
    print(f"Errors: {len(errors)}")
    
    if errors:
        print("\n❌ Failed inserts:")
        for err in errors:
            print(f"  Row {err['row']}: {err['activity']} - {err['question'][:50]}")
            print(f"    Error: {err['error']}")
    
    return inserted_count, errors


if __name__ == "__main__":
    print("🔧 Manually Inserting Failed Questions")
    print("="*60)
    
    inserted, errors = manual_insert_failed()
    
    if errors:
        print(f"\n⚠️  {len(errors)} records failed. Review errors above.")
    else:
        print("\n✅ All failed questions processed!")


