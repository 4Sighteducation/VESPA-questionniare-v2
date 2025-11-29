"""
Test what connections aramsey actually has in Knack
"""
import requests
import json
import os
from pathlib import Path
from dotenv import load_dotenv

env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

KNACK_APP_ID = os.getenv('KNACK_APP_ID')
KNACK_API_KEY = os.getenv('KNACK_API_KEY')

headers = {
    'X-Knack-Application-Id': KNACK_APP_ID,
    'X-Knack-REST-API-KEY': KNACK_API_KEY
}

print("=" * 80)
print("🔍 Testing aramsey@vespa.academy Connections in Knack")
print("=" * 80)
print()

# Get aramsey from Object_6
response = requests.get(
    'https://api.knack.com/v1/objects/object_6/records',
    headers=headers,
    params={
        'filters': json.dumps({
            'match': 'and',
            'rules': [
                {'field': 'field_91', 'operator': 'is', 'value': 'aramsey@vespa.academy'}
            ]
        })
    }
)

if response.status_code != 200:
    print(f"❌ API Error: {response.text}")
    exit(1)

students = response.json().get('records', [])

if not students:
    print("❌ aramsey@vespa.academy not found in Object_6!")
    exit(1)

student = students[0]

print("✅ Found aramsey in Knack Object_6")
print()
print("=" * 80)
print("CONNECTION FIELDS:")
print("=" * 80)

# Staff Admins (field_190)
print(f"\nStaff Admins (field_190_raw):")
print(json.dumps(student.get('field_190_raw', []), indent=2))

# Tutors (field_1682)
print(f"\nTutors (field_1682_raw):")
print(json.dumps(student.get('field_1682_raw', []), indent=2))

# HOYs (field_547)
print(f"\nHeads of Year (field_547_raw):")
print(json.dumps(student.get('field_547_raw', []), indent=2))

# Teachers (field_2177)
print(f"\nSubject Teachers (field_2177_raw):")
print(json.dumps(student.get('field_2177_raw', []), indent=2))

print("\n" + "=" * 80)
print("EXPECTED vs ACTUAL:")
print("=" * 80)
print(f"\nExpected tutor: tut7@vespa.academy")
print(f"Actual tutors in Knack: {student.get('field_1682_raw', [])}")
print()

# Also check formatted version
print("=" * 80)
print("FORMATTED FIELDS (for comparison):")
print("=" * 80)
print(f"\nfield_1682 (formatted): {student.get('field_1682')}")

