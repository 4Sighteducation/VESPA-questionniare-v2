"""
Analyze aramsey CSV to see how many valid records exist
"""

import csv
import json
from datetime import datetime

csv_file = r"C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\Homepage\activityanswers (2).csv"

print("=" * 80)
print("ANALYZING ARAMSEY CSV DATA")
print("=" * 80)
print()

valid_with_answers = []
empty_json = []
just_dot = []
parse_errors = []

with open(csv_file, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    
    for idx, row in enumerate(reader, start=2):  # Start at 2 (line 1 is header)
        date_str = row.get('Date/Time', '')
        activity_name = row.get('Activities', '')
        json_field = row.get('Activity Answers Name', '')
        
        if not date_str:
            continue
        
        # Parse date
        try:
            date = datetime.strptime(date_str, '%d/%m/%Y %H:%M')
        except:
            continue
        
        # Check if 2025
        if date.year < 2025:
            continue
        
        # Categorize by JSON validity
        if json_field == '.':
            just_dot.append({
                'line': idx,
                'date': date_str,
                'activity': activity_name
            })
        elif json_field == '{}' or not json_field.strip():
            empty_json.append({
                'line': idx,
                'date': date_str,
                'activity': activity_name
            })
        else:
            # Try to parse JSON
            try:
                data = json.loads(json_field)
                
                # Count non-empty values
                non_empty = 0
                for q_id, q_data in data.items():
                    if isinstance(q_data, dict):
                        cycle_data = q_data.get('cycle_1', {})
                        value = cycle_data.get('value', '')
                        if value and value.strip():
                            non_empty += 1
                
                if non_empty > 0:
                    valid_with_answers.append({
                        'line': idx,
                        'date': date_str,
                        'activity': activity_name,
                        'questions_answered': non_empty
                    })
                else:
                    empty_json.append({
                        'line': idx,
                        'date': date_str,
                        'activity': activity_name
                    })
                    
            except json.JSONDecodeError as e:
                parse_errors.append({
                    'line': idx,
                    'date': date_str,
                    'activity': activity_name,
                    'error': str(e)
                })

print(f"TOTAL 2025 RECORDS: {len(valid_with_answers) + len(empty_json) + len(just_dot) + len(parse_errors)}")
print()

print(f"✅ VALID WITH ANSWERS: {len(valid_with_answers)}")
for record in valid_with_answers:
    print(f"   Line {record['line']}: {record['activity']} ({record['questions_answered']} questions) - {record['date']}")

print()

print(f"❌ EMPTY JSON ({{}}): {len(empty_json)}")
for record in empty_json[:5]:
    print(f"   Line {record['line']}: {record['activity']} - {record['date']}")
if len(empty_json) > 5:
    print(f"   ... and {len(empty_json) - 5} more")

print()

print(f"❌ JUST DOT (.): {len(just_dot)}")
for record in just_dot[:5]:
    print(f"   Line {record['line']}: {record['activity']} - {record['date']}")
if len(just_dot) > 5:
    print(f"   ... and {len(just_dot) - 5} more")

print()

print(f"❌ JSON PARSE ERRORS: {len(parse_errors)}")
for record in parse_errors:
    print(f"   Line {record['line']}: {record['activity']} - {record['error']}")

print()
print("=" * 80)
print("SUMMARY")
print("=" * 80)
print(f"Valid records worth migrating: {len(valid_with_answers)}")
print(f"Invalid/Empty records: {len(empty_json) + len(just_dot) + len(parse_errors)}")
print()
print("RECOMMENDATION:")
if len(valid_with_answers) > 0:
    print(f"  ✅ Migrate the {len(valid_with_answers)} valid records")
    print(f"  ❌ Skip the {len(empty_json) + len(just_dot)} empty/invalid records (no useful data)")
else:
    print("  ⚠️ No valid records with actual question answers")

