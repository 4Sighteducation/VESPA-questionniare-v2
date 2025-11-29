"""
VESPA Activities V3 - Migration Script 4
Migrates 6,060 historical activity responses from Knack Object_46 to Supabase
Filters: completion_date >= 2025-01-01 AND student_email IS NOT NULL
"""
import os
import json
import requests
from datetime import datetime
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

# Knack API credentials
KNACK_APP_ID = os.environ.get("KNACK_APP_ID")
KNACK_API_KEY = os.environ.get("KNACK_API_KEY")

KNACK_HEADERS = {
    'X-Knack-Application-Id': KNACK_APP_ID,
    'X-Knack-REST-API-Key': KNACK_API_KEY,
    'Content-Type': 'application/json'
}

def parse_knack_date(date_value):
    """Parse Knack date field (handles multiple formats)"""
    if not date_value:
        return None
    
    # Try ISO format first
    try:
        return datetime.fromisoformat(date_value.replace('Z', '+00:00')).isoformat()
    except:
        pass
    
    # Try mm/dd/yyyy
    try:
        dt = datetime.strptime(date_value, "%m/%d/%Y")
        return dt.isoformat()
    except:
        pass
    
    # Try dd/mm/yyyy
    try:
        dt = datetime.strptime(date_value, "%d/%m/%Y")
        return dt.isoformat()
    except:
        pass
    
    # Try with time
    try:
        dt = datetime.strptime(date_value, "%m/%d/%Y %H:%M")
        return dt.isoformat()
    except:
        pass
    
    return None


def migrate_historical_responses():
    """Migrate historical responses from Knack Object_46"""
    
    # Build activity knack_id → UUID mapping
    print("📂 Fetching activities from Supabase...")
    activities_result = supabase.table("activities").select("id, knack_id, name").execute()
    activity_uuid_map = {a["knack_id"]: a["id"] for a in activities_result.data}
    print(f"✅ Loaded {len(activity_uuid_map)} activity mappings")
    
    # Fetch from Knack API with pagination
    filters = {
        "match": "and",
        "rules": [
            {
                "field": "field_1870",  # completion_date
                "operator": "is after",
                "value": "01/01/2025"
            },
            {
                "field": "field_1301",  # student connection
                "operator": "is not blank"
            }
        ]
    }
    
    page = 1
    rows_per_page = 1000
    migrated_count = 0
    errors = []
    student_emails_created = set()
    skipped_no_student = 0
    skipped_no_activity = 0
    skipped_invalid_json = 0
    
    print("\n🔄 Fetching records from Knack API...")
    
    while True:
        print(f"\n📄 Fetching page {page}...")
        
        params = {
            "filters": json.dumps(filters),
            "rows_per_page": rows_per_page,
            "page": page
        }
        
        try:
            response = requests.get(
                "https://api.knack.com/v1/objects/object_46/records",
                headers=KNACK_HEADERS,
                params=params
            )
            
            if response.status_code != 200:
                print(f"❌ Knack API error: {response.status_code} - {response.text}")
                break
            
            data = response.json()
            records = data.get("records", [])
            total_pages = data.get("total_pages", 1)
            current_count = data.get("current_page", page)
            
            print(f"📦 Retrieved {len(records)} records (page {current_count}/{total_pages}) - {migrated_count} migrated so far")
            
            if not records:
                break  # No more records
            
            for record in records:
                try:
                    # Extract student email from connection
                    student_connection = record.get("field_1301_raw", [])
                    if not student_connection or len(student_connection) == 0:
                        continue
                    
                    student_email = student_connection[0].get("identifier", "")
                    
                    # Extract email from HTML if wrapped in anchor tag
                    if '<a href="mailto:' in student_email:
                        import re
                        email_match = re.search(r'mailto:([^"]+)', student_email)
                        if email_match:
                            student_email = email_match.group(1)
                    
                    # Also strip any remaining HTML tags
                    student_email = re.sub(r'<[^>]+>', '', student_email).strip()
                    if not student_email:
                        continue
                    
                    # Extract activity Knack ID
                    activity_connection = record.get("field_1302_raw", [])
                    if not activity_connection or len(activity_connection) == 0:
                        continue
                    
                    activity_knack_id = activity_connection[0].get("id", "")
                    
                    # Get activity UUID
                    if activity_knack_id not in activity_uuid_map:
                        print(f"⚠️  Activity knack_id not found: {activity_knack_id}")
                        continue
                    
                    activity_uuid = activity_uuid_map[activity_knack_id]
                    
                    # Parse responses JSON (field_1300)
                    responses_json = {}
                    try:
                        raw_json = record.get("field_1300", "")
                        if raw_json:
                            responses_json = json.loads(raw_json) if isinstance(raw_json, str) else raw_json
                    except json.JSONDecodeError:
                        # Invalid JSON, skip
                        pass
                    
                    # Parse completion date
                    completion_date = parse_knack_date(record.get("field_1870"))
                    
                    # Ensure student exists in vespa_students table
                    if student_email not in student_emails_created:
                        student_knack_id = student_connection[0].get("id", "")
                        student_name_parts = student_connection[0].get("identifier", "").split()
                        
                        # Create vespa_students record (canonical registry)
                        supabase.table("vespa_students").upsert({
                            "email": student_email,
                            "current_knack_id": student_knack_id,
                            "historical_knack_ids": [student_knack_id],
                            "first_name": student_name_parts[0] if len(student_name_parts) > 0 else "",
                            "last_name": student_name_parts[-1] if len(student_name_parts) > 1 else "",
                            "full_name": student_connection[0].get("identifier", ""),
                            "auth_provider": "knack",
                            "status": "active",
                            "is_active": True
                        }, on_conflict="email").execute()
                        
                        student_emails_created.add(student_email)
                    
                    # Insert response
                    response_data = {
                        "knack_id": record["id"],
                        "student_email": student_email,
                        "activity_id": activity_uuid,
                        "cycle_number": 1,  # Assume cycle 1 for historical data
                        "responses": responses_json,
                        "responses_text": record.get("field_2334", ""),
                        "status": ("completed" if completion_date else "in_progress")[:50],  # Truncate to 50 chars
                        "completed_at": completion_date,
                        "staff_feedback": record.get("field_1734", ""),
                        "year_group": (record.get("field_2331", "") or "")[:50],  # Truncate to 50 chars
                        "student_group": (record.get("field_2332", "") or "")[:100]  # Truncate to 100 chars
                    }
                    
                    # Handle staff feedback metadata
                    if record.get("field_1872_raw"):  # Tutor connection
                        response_data["staff_feedback_by"] = record["field_1872_raw"][0].get("identifier", "")
                    elif record.get("field_1873_raw"):  # Staff admin connection
                        response_data["staff_feedback_by"] = record["field_1873_raw"][0].get("identifier", "")
                    
                    # Upsert into Supabase (safe for re-runs)
                    supabase.table("activity_responses").upsert(
                        response_data,
                        on_conflict="student_email,activity_id,cycle_number"
                    ).execute()
                    migrated_count += 1
                    
                    if migrated_count % 100 == 0:
                        print(f"  ✅ {migrated_count} responses migrated (Page {page})...")
                    
                except Exception as e:
                    errors.append({
                        "record_id": record.get("id", "Unknown"),
                        "error": str(e)
                    })
            
            # Move to next page
            if page >= total_pages:
                break
            
            page += 1
            
        except Exception as e:
            print(f"❌ Error on page {page}: {e}")
            print(f"   Skipping page and continuing...")
            errors.append({
                "page": page,
                "error": str(e)
            })
            page += 1
            continue
    
    # Print summary
    print("\n" + "="*60)
    print(f"📊 MIGRATION SUMMARY")
    print("="*60)
    print(f"Total responses migrated: {migrated_count}")
    print(f"Unique students created: {len(student_emails_created)}")
    print(f"Errors: {len(errors)}")
    
    if errors:
        print("\n❌ Failed migrations (first 10):")
        for err in errors[:10]:
            print(f"  - Record {err['record_id']}: {err['error']}")
        
        if len(errors) > 10:
            print(f"  ... and {len(errors) - 10} more errors")
    else:
        print("\n✅ All historical responses migrated successfully!")
    
    return migrated_count, errors


if __name__ == "__main__":
    print("🚀 Starting VESPA Activities Migration - Step 4: Historical Responses")
    print("="*60)
    print("⚠️  This may take 10-15 minutes for 6,000+ records")
    print("="*60)
    
    migrated, errors = migrate_historical_responses()
    
    if errors:
        print("\n⚠️  Migration completed with errors. Please review above.")
        exit(1)
    else:
        print("\n🎉 Migration Step 4 completed successfully!")
        print("➡️  Next: Run 05_seed_achievements.py")
        exit(0)

