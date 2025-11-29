"""
Quick test to see what Knack actually returns
"""
import requests
import json
import sys
import os
from pathlib import Path
from dotenv import load_dotenv

# Load from .env file (same as migration script)
env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

KNACK_APP_ID = os.getenv('KNACK_APP_ID')
KNACK_API_KEY = os.getenv('KNACK_API_KEY')

print(f"Loaded App ID: {KNACK_APP_ID}")
print(f"Loaded API Key: {KNACK_API_KEY[:20] if KNACK_API_KEY else 'NOT FOUND'}...")
print()

headers = {
    'X-Knack-Application-Id': KNACK_APP_ID,
    'X-Knack-REST-API-KEY': KNACK_API_KEY
}

print("Fetching sample account from Object_3...")
print(f"Using App ID: {headers['X-Knack-Application-Id']}")
print(f"API Key: {headers['X-Knack-REST-API-KEY'][:20]}...")
print()

# Get first VESPA ACADEMY account (simpler - no filters first)
response = requests.get(
    'https://api.knack.com/v1/objects/object_3/records',
    headers=headers,
    params={'rows_per_page': 3}
)

print(f"Status Code: {response.status_code}")

if response.status_code != 200:
    print(f"❌ API Error!")
    print(f"Response: {response.text}")
    print(f"\nHeaders sent: {headers}")
    sys.exit(1)

print(f"Response length: {len(response.text)} bytes")
print(f"Content-Type: {response.headers.get('Content-Type')}")
print()

try:
    data = response.json()
    accounts = data.get('records', [])
    print(f"✅ Parsed JSON successfully")
    print(f"Total records in response: {data.get('total_records', 'unknown')}")
    print(f"Records returned: {len(accounts)}")
except Exception as e:
    print(f"❌ Failed to parse JSON: {e}")
    print(f"Raw response (first 1000 chars):")
    print(response.text[:1000])
    sys.exit(1)

if not accounts:
    print("No accounts found!")
else:
    print(f"\n✅ Found {len(accounts)} accounts\n")
    
    # Show first account
    account = accounts[0]
    
    print("=" * 80)
    print("SAMPLE ACCOUNT:")
    print("=" * 80)
    print(f"Email (field_70): {account.get('field_70')}")
    print(f"\nRoles (field_73):")
    print(f"  Value: {account.get('field_73')}")
    print(f"  Type: {type(account.get('field_73'))}")
    
    print(f"\nName (field_69):")
    print(f"  Value: {account.get('field_69')}")
    print(f"  Type: {type(account.get('field_69'))}")
    
    print(f"\nEstablishment (field_122):")
    print(f"  Value: {account.get('field_122')}")
    
    print("\n" + "=" * 80)
    print("FULL ACCOUNT STRUCTURE:")
    print("=" * 80)
    print(json.dumps(account, indent=2))

