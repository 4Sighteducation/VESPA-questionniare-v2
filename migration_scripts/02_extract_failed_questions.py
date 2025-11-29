"""
Extract failed/skipped questions from CSV for manual review
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

def extract_failed_questions():
    """Extract questions that failed or were skipped during migration"""
    
    # Fetch all activities to create name→UUID mapping
    print("📂 Fetching activities from Supabase...")
    activities_result = supabase.table("activities").select("id, name, knack_id").execute()
    activity_map = {a["name"]: a["id"] for a in activities_result.data}
    print(f"✅ Loaded {len(activity_map)} activities")
    
    # Fetch already migrated questions
    print("📂 Fetching already migrated questions...")
    migrated_questions = supabase.table("activity_questions").select("activity_id, question_title, display_order").execute()
    
    # Create a set of (activity_id, question_title) tuples for quick lookup
    migrated_set = set()
    for q in migrated_questions.data:
        migrated_set.add((q["activity_id"], q["question_title"].strip().lower()))
    
    print(f"✅ Found {len(migrated_set)} already migrated questions")
    
    # Load CSV
    csv_path = os.path.join(
        os.path.dirname(__file__),
        '..',
        'activityquestion.csv'
    )
    
    print(f"📂 Loading questions from: {csv_path}")
    
    failed_records = []
    skipped_records = []
    
    with open(csv_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        
        for row_num, row in enumerate(reader, start=2):  # Start at 2 (row 1 is header)
            # Normalize column names
            row_normalized = {k.strip(): v for k, v in row.items()}
            
            activity_name = row_normalized.get("Activity", "").strip()
            question_title = row_normalized.get("Question Title", "").strip()
            active_value = row_normalized.get("Active", "").strip()
            
            # Skip if no activity name
            if not activity_name:
                skipped_records.append({
                    "row_number": row_num,
                    "reason": "No activity name",
                    **row_normalized
                })
                continue
            
            # Skip if inactive
            if active_value != "True":
                skipped_records.append({
                    "row_number": row_num,
                    "reason": "Inactive",
                    **row_normalized
                })
                continue
            
            # Check if activity exists
            if activity_name not in activity_map:
                skipped_records.append({
                    "row_number": row_num,
                    "reason": f"Activity '{activity_name}' not found in Supabase",
                    **row_normalized
                })
                continue
            
            activity_id = activity_map[activity_name]
            
            # Check if question was migrated
            question_key = (activity_id, question_title.lower())
            if question_key not in migrated_set:
                failed_records.append({
                    "row_number": row_num,
                    "reason": "Not found in migrated questions",
                    "activity_id": activity_id,
                    **row_normalized
                })
    
    # Write failed records to CSV
    output_file = os.path.join(
        os.path.dirname(__file__),
        'failed_questions.csv'
    )
    
    all_failed = failed_records + skipped_records
    
    if all_failed:
        print(f"\n📝 Writing {len(all_failed)} failed/skipped records to: {output_file}")
        
        with open(output_file, 'w', newline='', encoding='utf-8') as f:
            if all_failed:
                fieldnames = ['row_number', 'reason', 'activity_id', 'Activity', 'Question Title', 
                             'Order', 'Type', 'Active', 'Text Above Question', 
                             'Dropdown/Checkbox options', 'Answer Required?', 
                             'Show in Final Questions Section']
                
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()
                
                for record in all_failed:
                    writer.writerow(record)
        
        print(f"✅ Exported {len(all_failed)} records to {output_file}")
        
        # Print summary
        print("\n" + "="*60)
        print("📊 SUMMARY")
        print("="*60)
        print(f"Failed (not migrated): {len(failed_records)}")
        print(f"Skipped (inactive/no activity): {len(skipped_records)}")
        print(f"Total: {len(all_failed)}")
        
        if failed_records:
            print("\n❌ Failed Records:")
            for rec in failed_records[:10]:
                print(f"  Row {rec['row_number']}: {rec['Activity']} - {rec['Question Title'][:50]}")
        
        if skipped_records:
            print("\n⚠️  Skipped Records:")
            reasons = {}
            for rec in skipped_records:
                reason = rec['reason']
                reasons[reason] = reasons.get(reason, 0) + 1
            for reason, count in reasons.items():
                print(f"  {reason}: {count}")
    else:
        print("\n✅ All questions were successfully migrated!")
    
    return all_failed


if __name__ == "__main__":
    print("🔍 Extracting Failed/Skipped Questions")
    print("="*60)
    
    failed = extract_failed_questions()
    
    if failed:
        print(f"\n📄 Review failed_questions.csv for details")
        print("💡 You can manually insert these records or fix issues and re-run")
    else:
        print("\n✅ No failed records found!")


