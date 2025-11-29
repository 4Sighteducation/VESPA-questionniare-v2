"""
Check why migration script 04 only imported 1000 records
"""

import os
from pathlib import Path
from dotenv import load_dotenv
import requests
import json

env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

KNACK_APP_ID = os.getenv('KNACK_APP_ID')
KNACK_API_KEY = os.getenv('KNACK_API_KEY')

headers = {
    'X-Knack-Application-Id': KNACK_APP_ID,
    'X-Knack-REST-API-Key': KNACK_API_KEY
}

print("Checking migration 04 pagination...")
print()

# Same filters as migration script
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

params = {
    "filters": json.dumps(filters),
    "rows_per_page": 1,
    "page": 1
}

print("Testing with same filters as migration script...")
response = requests.get(
    "https://api.knack.com/v1/objects/object_46/records",
    headers=headers,
    params=params
)

print(f"Status: {response.status_code}")

if response.status_code == 200:
    data = response.json()
    print(f"Total pages: {data.get('total_pages')}")
    print(f"Total records matching filter: {data.get('total_records')}")
    print(f"Current page: {data.get('current_page')}")
    print()
    
    if data.get('total_pages') == 1:
        print("⚠️ PROBLEM: Knack says only 1 page exists with filters!")
        print("   This means only 1000 records match the filter")
        print("   aramsey's records might be on 'page 2' logically but filtered out")
    else:
        print(f"✅ {data.get('total_pages')} pages should have been processed")
        print(f"   But migration only imported 1000 records (1 page)")
        print(f"   Script likely stopped early or hit error")
else:
    print(f"Error: {response.text}")

print()
print("Checking WITHOUT date filter (all records with student)...")

# No date filter
filters_no_date = {
    "match": "and",
    "rules": [
        {
            "field": "field_1301",  # student connection
            "operator": "is not blank"
        }
    ]
}

params_no_date = {
    "filters": json.dumps(filters_no_date),
    "rows_per_page": 1,
    "page": 1
}

response = requests.get(
    "https://api.knack.com/v1/objects/object_46/records",
    headers=headers,
    params=params_no_date
)

if response.status_code == 200:
    data = response.json()
    print(f"Total records (no date filter): {data.get('total_records')}")
    print(f"Total pages: {data.get('total_pages')}")

