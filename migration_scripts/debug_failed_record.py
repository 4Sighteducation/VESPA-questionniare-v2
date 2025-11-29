"""
Debug: Check what's in a failed record to see which field is too long
"""

import os
from pathlib import Path
from dotenv import load_dotenv
import requests

env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

KNACK_APP_ID = os.getenv('KNACK_APP_ID')
KNACK_API_KEY = os.getenv('KNACK_API_KEY')

# One of the failed record IDs
FAILED_RECORD_ID = '681cf6624fff34030268b6e4'

headers = {
    'X-Knack-Application-Id': KNACK_APP_ID,
    'X-Knack-REST-API-Key': KNACK_API_KEY
}

print(f"Fetching failed record: {FAILED_RECORD_ID}")
print()

response = requests.get(
    f"https://api.knack.com/v1/objects/object_46/records/{FAILED_RECORD_ID}",
    headers=headers
)

if response.status_code != 200:
    print(f"Error: {response.status_code}")
else:
    record = response.json()
    
    print("Checking VARCHAR field lengths:")
    print()
    
    # Check all VARCHAR fields that go into activity_responses
    fields_to_check = {
        'field_2331': ('year_group', 50),
        'field_2332': ('student_group', 100),
        'field_1734': ('staff_feedback', None),  # TEXT field, no limit
        'field_1300': ('Activity Answers JSON', None),  # Goes to JSONB
        'field_2334': ('responses_text', None),  # TEXT field
    }
    
    for field_id, (field_name, max_length) in fields_to_check.items():
        value = record.get(field_id, '') or ''
        raw_value = record.get(f"{field_id}_raw", '') or ''
        
        actual_value = raw_value if raw_value else value
        
        if isinstance(actual_value, list):
            actual_value = str(actual_value)
        
        length = len(str(actual_value))
        
        status = "OK"
        if max_length and length > max_length:
            status = f"TOO LONG! ({length} > {max_length})"
        
        print(f"{field_name} ({field_id}):")
        print(f"  Length: {length} chars")
        print(f"  Limit: {max_length or 'None (TEXT)'}")
        print(f"  Status: {status}")
        if length > 0 and length < 200:
            print(f"  Value: {str(actual_value)[:150]}")
        print()
    
    # Check student email from connection
    student_conn = record.get('field_1301_raw', [])
    if student_conn:
        student_email = student_conn[0].get('identifier', '')
        print(f"Student email (field_1301):")
        print(f"  Length: {len(student_email)}")
        print(f"  Limit: 255")
        print(f"  Value: {student_email}")
        print()
    
    # Check activity connection
    activity_conn = record.get('field_1302_raw', [])
    if activity_conn:
        activity_name = activity_conn[0].get('identifier', '')
        print(f"Activity name (field_1302):")
        print(f"  Length: {len(activity_name)}")
        print(f"  Value: {activity_name}")
        print()

