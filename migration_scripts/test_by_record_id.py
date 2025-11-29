"""
Test: Fetch student by correct record ID
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv
import requests
import json

env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

KNACK_APP_ID = os.getenv('KNACK_APP_ID')
KNACK_API_KEY = os.getenv('KNACK_API_KEY')
KNACK_API_BASE = 'https://api.knack.com/v1'

# Correct record ID from user
CORRECT_RECORD_ID = '6911e6712f6ab302e8c7209c'

def fetch_student_by_id(record_id):
    """Fetch student directly by record ID"""
    url = f"{KNACK_API_BASE}/objects/object_6/records/{record_id}"
    
    headers = {
        'X-Knack-Application-Id': KNACK_APP_ID,
        'X-Knack-REST-API-Key': KNACK_API_KEY
    }
    
    response = requests.get(url, headers=headers)
    
    print(f"Status Code: {response.status_code}")
    
    if response.status_code != 200:
        print(f"Error: {response.text}")
        return None
    
    return response.json()


def main():
    print("Fetching student record: " + CORRECT_RECORD_ID)
    print()
    
    student = fetch_student_by_id(CORRECT_RECORD_ID)
    
    if not student:
        print("Failed to fetch student")
        return
    
    print("SUCCESS - Found student!")
    print()
    
    # Check email
    email = student.get('field_91') or student.get('field_91_raw')
    print(f"Email (field_91): {email}")
    print()
    
    # Check field_1683 - Prescribed Activities
    print("=" * 80)
    print("field_1683 - PRESCRIBED ACTIVITIES")
    print("=" * 80)
    field_1683 = student.get('field_1683', '')
    field_1683_raw = student.get('field_1683_raw', [])
    
    print(f"field_1683 type: {type(field_1683)}")
    print(f"field_1683 length: {len(field_1683) if field_1683 else 0}")
    print(f"field_1683 value: {field_1683[:500] if isinstance(field_1683, str) else field_1683}")
    print()
    print(f"field_1683_raw type: {type(field_1683_raw)}")
    print(f"field_1683_raw: {field_1683_raw}")
    print()
    
    # Parse HTML
    if isinstance(field_1683, str) and field_1683.strip():
        import re
        pattern = r'<span class="([a-f0-9]{24})"[^>]*>([^<]+)</span>'
        matches = re.findall(pattern, field_1683)
        print(f"Extracted {len(matches)} activities from HTML:")
        for knack_id, name in matches:
            print(f"  - {name} (ID: {knack_id})")
    
    # Check field_1380 - Finished Activities
    print()
    print("=" * 80)
    print("field_1380 - FINISHED ACTIVITIES")
    print("=" * 80)
    field_1380 = student.get('field_1380', '')
    field_1380_raw = student.get('field_1380_raw', '')
    
    print(f"field_1380: {field_1380}")
    print(f"field_1380_raw: {field_1380_raw}")
    
    if field_1380:
        ids = field_1380.split(',')
        print(f"Count: {len(ids)}")
        print(f"IDs: {ids}")
    
    # Check field_3656 - Activity History
    print()
    print("=" * 80)
    print("field_3656 - ACTIVITY HISTORY")
    print("=" * 80)
    field_3656 = student.get('field_3656', '')
    field_3656_raw = student.get('field_3656_raw', '')
    
    if field_3656:
        print(f"Length: {len(field_3656)}")
        try:
            history = json.loads(field_3656)
            print(f"Parsed JSON successfully!")
            if 'cycle1' in history:
                print(f"  Cycle 1 prescribed: {len(history['cycle1'].get('prescribed', []))}")
                print(f"  Cycle 1 selected: {len(history['cycle1'].get('selected', []))}")
                print(f"  Cycle 1 completed: {len(history['cycle1'].get('completed', []))}")
                if history['cycle1'].get('prescribed'):
                    print(f"  Activities: {history['cycle1']['prescribed'][:3]}")
        except:
            print(f"Could not parse as JSON")
            print(f"Value: {field_3656[:200]}")

if __name__ == "__main__":
    main()


