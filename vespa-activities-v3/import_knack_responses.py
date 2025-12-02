#!/usr/bin/env python3
"""
Import Knack Activity Responses to Supabase
=============================================
This script imports activity responses from a Knack CSV export (object_46)
into the Supabase activity_responses table.

Usage:
    python import_knack_responses.py latestanswers.csv

CSV Columns Expected:
- Student (email)
- Activities (activity name)
- Actvity Answers (JSON with question responses)
- Date/Time (completion date)
- Yes/No (completed status)
- Feedback (optional staff feedback)
- Feedback Read (true/false)
- new_feedback_given (true/false)
"""

import csv
import json
import sys
import os
from datetime import datetime
from supabase import create_client, Client

# Supabase configuration - use environment variables
SUPABASE_URL = os.environ.get('SUPABASE_URL', 'https://qcdcdzfanrlvdcagmwmg.supabase.co')
SUPABASE_KEY = os.environ.get('SUPABASE_SERVICE_KEY') or os.environ.get('SUPABASE_KEY')

def get_supabase_client():
    """Create Supabase client"""
    if not SUPABASE_KEY:
        print("ERROR: SUPABASE_SERVICE_KEY or SUPABASE_KEY environment variable not set")
        print("Please set it: export SUPABASE_SERVICE_KEY='your-service-key-here'")
        sys.exit(1)
    
    return create_client(SUPABASE_URL, SUPABASE_KEY)


def load_activity_mappings(supabase: Client):
    """
    Load activity name -> ID mappings from Supabase
    Returns dict: { "activity_name": "activity_uuid" }
    """
    print("Loading activity mappings from Supabase...")
    
    result = supabase.table('activities').select('id, name').execute()
    
    mappings = {}
    for activity in result.data:
        # Use lowercase for case-insensitive matching
        name = activity['name'].strip().lower()
        mappings[name] = activity['id']
    
    print(f"Loaded {len(mappings)} activity mappings")
    return mappings


def parse_knack_date(date_str):
    """Parse Knack date format (e.g., '02/12/2025 16:24')"""
    if not date_str:
        return None
    
    try:
        # Try common Knack date formats
        for fmt in ['%d/%m/%Y %H:%M', '%d/%m/%Y', '%m/%d/%Y %H:%M', '%m/%d/%Y']:
            try:
                return datetime.strptime(date_str.strip(), fmt).isoformat()
            except ValueError:
                continue
        return None
    except Exception as e:
        print(f"Warning: Could not parse date '{date_str}': {e}")
        return None


def parse_knack_responses(responses_json):
    """
    Parse Knack responses JSON format
    Input format: {"question_id": {"cycle_1": {"value": "answer"}}, ...}
    Output format: {"question_id": "answer", ...}
    """
    if not responses_json:
        return {}
    
    try:
        if isinstance(responses_json, str):
            data = json.loads(responses_json)
        else:
            data = responses_json
        
        # Flatten the nested structure
        result = {}
        for q_id, cycles in data.items():
            if isinstance(cycles, dict):
                # Get value from first available cycle
                for cycle_key, cycle_data in cycles.items():
                    if isinstance(cycle_data, dict) and 'value' in cycle_data:
                        result[q_id] = cycle_data['value']
                        break
            elif isinstance(cycles, str):
                result[q_id] = cycles
        
        return result
    except json.JSONDecodeError as e:
        print(f"Warning: Could not parse JSON responses: {e}")
        return {}


def import_csv(csv_path: str, dry_run: bool = False):
    """
    Import CSV file into Supabase activity_responses table
    
    Args:
        csv_path: Path to CSV file
        dry_run: If True, only simulate the import without writing
    """
    supabase = get_supabase_client()
    activity_mappings = load_activity_mappings(supabase)
    
    # Statistics
    stats = {
        'total_rows': 0,
        'imported': 0,
        'skipped_no_activity': 0,
        'skipped_no_student': 0,
        'skipped_unmapped': 0,
        'errors': 0,
        'unmapped_activities': set()
    }
    
    print(f"\nReading CSV: {csv_path}")
    print("=" * 60)
    
    with open(csv_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        
        for row in reader:
            stats['total_rows'] += 1
            
            # Get required fields
            student_email = row.get('Student', '').strip()
            activity_name = row.get('Activities', '').strip()
            responses_json = row.get('Actvity Answers') or row.get('Activity Answers Name', '')
            date_str = row.get('Date/Time', '')
            is_completed = row.get('Yes/No', '').lower() == 'yes'
            feedback = row.get('Feedback', '').strip() or None
            feedback_read = row.get('Feedback Read', '').lower() == 'yes'
            
            # Validate required fields
            if not student_email:
                stats['skipped_no_student'] += 1
                continue
            
            if not activity_name:
                stats['skipped_no_activity'] += 1
                continue
            
            # Map activity name to ID
            activity_id = activity_mappings.get(activity_name.lower())
            if not activity_id:
                stats['skipped_unmapped'] += 1
                stats['unmapped_activities'].add(activity_name)
                continue
            
            # Parse responses
            responses = parse_knack_responses(responses_json)
            
            # Parse date
            completed_at = parse_knack_date(date_str) if is_completed else None
            
            # Build response record (only columns that exist in activity_responses)
            response_record = {
                'student_email': student_email,
                'activity_id': activity_id,
                'cycle_number': 1,  # Default to cycle 1 for imported data
                'status': 'completed' if is_completed else 'assigned',
                'responses': responses if responses else None,
                'staff_feedback': feedback,
                'feedback_read_by_student': feedback_read,
                'completed_at': completed_at
            }
            
            # Calculate word count from responses
            if responses:
                word_count = sum(len(str(v).split()) for v in responses.values() if v)
                response_record['word_count'] = word_count
            
            if dry_run:
                print(f"[DRY RUN] Would import: {student_email} -> {activity_name}")
                stats['imported'] += 1
            else:
                try:
                    # Check if record already exists
                    existing = supabase.table('activity_responses').select('id')\
                        .eq('student_email', student_email)\
                        .eq('activity_id', activity_id)\
                        .eq('cycle_number', 1)\
                        .execute()
                    
                    if existing.data:
                        # Update existing record
                        supabase.table('activity_responses').update(response_record)\
                            .eq('id', existing.data[0]['id'])\
                            .execute()
                        print(f"Updated: {student_email} -> {activity_name}")
                    else:
                        # Insert new record
                        supabase.table('activity_responses').insert(response_record).execute()
                        print(f"Imported: {student_email} -> {activity_name}")
                    
                    stats['imported'] += 1
                    
                except Exception as e:
                    print(f"ERROR importing {student_email} -> {activity_name}: {e}")
                    stats['errors'] += 1
    
    # Print summary
    print("\n" + "=" * 60)
    print("IMPORT SUMMARY")
    print("=" * 60)
    print(f"Total rows processed: {stats['total_rows']}")
    print(f"Successfully imported: {stats['imported']}")
    print(f"Skipped (no student): {stats['skipped_no_student']}")
    print(f"Skipped (no activity): {stats['skipped_no_activity']}")
    print(f"Skipped (unmapped activity): {stats['skipped_unmapped']}")
    print(f"Errors: {stats['errors']}")
    
    if stats['unmapped_activities']:
        print(f"\nUnmapped activities ({len(stats['unmapped_activities'])}):")
        for name in sorted(stats['unmapped_activities']):
            print(f"  - {name}")
    
    return stats


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python import_knack_responses.py <csv_file> [--dry-run]")
        print("\nOptions:")
        print("  --dry-run  Simulate import without writing to database")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    dry_run = '--dry-run' in sys.argv
    
    if not os.path.exists(csv_file):
        print(f"ERROR: File not found: {csv_file}")
        sys.exit(1)
    
    if dry_run:
        print("=" * 60)
        print("DRY RUN MODE - No changes will be made to the database")
        print("=" * 60)
    
    import_csv(csv_file, dry_run=dry_run)

