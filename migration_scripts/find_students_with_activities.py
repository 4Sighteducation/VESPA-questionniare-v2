"""
Find students with activity data in Knack
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv
import requests

env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

KNACK_APP_ID = os.getenv('KNACK_APP_ID')
KNACK_API_KEY = os.getenv('KNACK_API_KEY')
KNACK_API_BASE = 'https://api.knack.com/v1'

def find_students_with_activities():
    """Find students with prescribed or finished activities"""
    
    url = f"{KNACK_API_BASE}/objects/object_6/records"
    headers = {
        'X-Knack-Application-Id': KNACK_APP_ID,
        'X-Knack-REST-API-Key': KNACK_API_KEY
    }
    
    print("🔍 Searching for students with activity data...\n")
    
    students_with_prescribed = []
    students_with_finished = []
    
    page = 1
    while page <= 3:  # Check first 3 pages (300 students)
        print(f"📄 Checking page {page}...")
        
        response = requests.get(url, headers=headers, params={'rows_per_page': 100, 'page': page})
        
        if response.status_code != 200:
            print(f"❌ Error: {response.status_code}")
            break
        
        data = response.json()
        records = data.get('records', [])
        
        if not records:
            break
        
        for record in records:
            email = record.get('field_91') or record.get('field_91_raw')
            
            # Handle dict format
            if isinstance(email, dict):
                email = email.get('email')
            
            # Check prescribed activities
            prescribed = record.get('field_1683') or record.get('field_1683_raw') or []
            if prescribed and len(prescribed) > 0:
                students_with_prescribed.append({
                    'email': email,
                    'count': len(prescribed) if isinstance(prescribed, list) else 1,
                    'data': prescribed
                })
            
            # Check finished activities
            finished = record.get('field_1380') or record.get('field_1380_raw') or ''
            if finished and len(finished) > 0:
                finished_count = len(finished.split(',')) if ',' in finished else 1
                students_with_finished.append({
                    'email': email,
                    'count': finished_count,
                    'data': finished
                })
        
        if page >= data.get('total_pages', 1):
            break
        
        page += 1
    
    print(f"\n✅ Found {len(students_with_prescribed)} students with prescribed activities")
    print(f"✅ Found {len(students_with_finished)} students with finished activities")
    
    if students_with_prescribed:
        print("\n📋 Sample students with PRESCRIBED activities:")
        for student in students_with_prescribed[:5]:
            print(f"   - {student['email']}: {student['count']} activities")
            print(f"     Sample: {student['data'][:200] if isinstance(student['data'], str) else student['data'][:2]}")
    
    if students_with_finished:
        print("\n✅ Sample students with FINISHED activities:")
        for student in students_with_finished[:5]:
            print(f"   - {student['email']}: {student['count']} completed")
            print(f"     IDs: {student['data'][:100]}")
    
    if not students_with_prescribed and not students_with_finished:
        print("\n⚠️ WARNING: No students found with activity data in first 300 records!")
        print("   Either:")
        print("   1. Activities feature hasn't been used yet")
        print("   2. Data is in different Knack app")
        print("   3. Field numbers are different")

if __name__ == "__main__":
    find_students_with_activities()


