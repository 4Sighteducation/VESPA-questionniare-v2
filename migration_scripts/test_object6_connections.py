"""
Quick test to see Object_6 connection field format
Much faster than processing 633 Object_3 accounts!
"""
import requests
import json
import sys
import os
from pathlib import Path
from dotenv import load_dotenv

# Load credentials
env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

KNACK_APP_ID = os.getenv('KNACK_APP_ID')
KNACK_API_KEY = os.getenv('KNACK_API_KEY')
VESPA_ACADEMY_KNACK_ID = '603e9f97cb8481001b31183d'

headers = {
    'X-Knack-Application-Id': KNACK_APP_ID,
    'X-Knack-REST-API-KEY': KNACK_API_KEY
}

print("=" * 80)
print("🔍 Testing Object_6 Connection Fields")
print("=" * 80)
print()

# Get a few VESPA ACADEMY students from Object_6
print("Fetching VESPA ACADEMY students from Object_6...")
response = requests.get(
    'https://api.knack.com/v1/objects/object_6/records',
    headers=headers,
    params={
        'rows_per_page': 10,
        'filters': json.dumps({
            'match': 'and',
            'rules': [
                {'field': 'field_179', 'operator': 'is', 'value': VESPA_ACADEMY_KNACK_ID}
            ]
        })
    }
)

if response.status_code != 200:
    print(f"❌ API Error: {response.text}")
    sys.exit(1)

students = response.json().get('records', [])
print(f"✅ Found {len(students)} students\n")

if not students:
    print("No students found!")
    sys.exit(1)

# Show first student
student = students[0]

print("=" * 80)
print("SAMPLE STUDENT RECORD:")
print("=" * 80)
print(f"Student Email (field_91): {student.get('field_91')}")
print(f"Student Name (field_90): {student.get('field_90')}")
print()

print("CONNECTION FIELDS:")
print("-" * 80)

# Staff Admins (field_190)
print(f"\nStaff Admins (field_190):")
print(f"  Formatted: {student.get('field_190')}")
print(f"  Raw: {student.get('field_190_raw')}")

# Tutors (field_1682)
print(f"\nTutors (field_1682):")
print(f"  Formatted: {student.get('field_1682')}")
print(f"  Raw: {student.get('field_1682_raw')}")

# Heads of Year (field_547)
print(f"\nHeads of Year (field_547):")
print(f"  Formatted: {student.get('field_547')}")
print(f"  Raw: {student.get('field_547_raw')}")

# Subject Teachers (field_2177)
print(f"\nSubject Teachers (field_2177):")
print(f"  Formatted: {student.get('field_2177')}")
print(f"  Raw: {student.get('field_2177_raw')}")

print("\n" + "=" * 80)
print("CONNECTION EXTRACTION TEST:")
print("=" * 80)

# Test extraction
def extract_emails(field_raw):
    """Test email extraction"""
    if not field_raw:
        return []
    if isinstance(field_raw, list):
        return [conn.get('identifier') if isinstance(conn, dict) else conn for conn in field_raw]
    return []

staff_admins = extract_emails(student.get('field_190_raw', []))
tutors = extract_emails(student.get('field_1682_raw', []))
hoys = extract_emails(student.get('field_547_raw', []))
teachers = extract_emails(student.get('field_2177_raw', []))

print(f"\nExtracted Emails:")
print(f"  Staff Admins: {staff_admins}")
print(f"  Tutors: {tutors}")
print(f"  HOYs: {hoys}")
print(f"  Teachers: {teachers}")

# Show a few more students for comparison
print("\n" + "=" * 80)
print("CONNECTION SUMMARY (All fetched students):")
print("=" * 80)

for idx, s in enumerate(students, 1):
    email = s.get('field_91')
    staff_admins_count = len(s.get('field_190_raw', []))
    tutors_count = len(s.get('field_1682_raw', []))
    hoys_count = len(s.get('field_547_raw', []))
    teachers_count = len(s.get('field_2177_raw', []))
    
    total_connections = staff_admins_count + tutors_count + hoys_count + teachers_count
    
    if total_connections > 0:
        print(f"{idx}. {email}:")
        if staff_admins_count: print(f"   - Staff Admins: {staff_admins_count}")
        if tutors_count: print(f"   - Tutors: {tutors_count}")
        if hoys_count: print(f"   - HOYs: {hoys_count}")
        if teachers_count: print(f"   - Teachers: {teachers_count}")

print("\n✅ Test complete!")

