"""
Migration Script: VESPA ACADEMY - BATCH OPTIMIZED
Purpose: Migrate VESPA ACADEMY with proper batching for large datasets
Version: 3.0 - Batch processing + Rate limiting
Features:
- Knack pagination (handles 1000+ records)
- Supabase batch inserts (100 records at a time)
- Rate limiting (respects Supabase limits)
- Progress indicators
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from supabase import create_client
import requests
import json
from datetime import datetime
import time
import re

# Load environment
env_path = Path(__file__).parent.parent.parent / 'DASHBOARD' / 'DASHBOARD' / '.env'
load_dotenv(env_path)

SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')
KNACK_APP_ID = os.getenv('KNACK_APP_ID', '66e26296d863e5001c6f1e09')
KNACK_API_KEY = os.getenv('KNACK_API_KEY', '0b19dcb0-9f43-11ef-8724-eb3bc75b770f')

# VESPA ACADEMY
VESPA_ACADEMY_ID = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
VESPA_ACADEMY_KNACK_ID = '603e9f97cb8481001b31183d'

# Batch settings
BATCH_SIZE = 100  # Insert 100 records at a time
RATE_LIMIT_DELAY = 0.5  # 500ms between batches

print("=" * 80)
print("🧪 VESPA ACADEMY MIGRATION (BATCH OPTIMIZED)")
print("=" * 80)
print(f"Supabase: {SUPABASE_URL}")
print(f"Batch size: {BATCH_SIZE} records")
print(f"Rate limit delay: {RATE_LIMIT_DELAY}s")
print()

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
print("✅ Supabase client initialized\n")


def get_knack_records(object_key, filters=None, rows_per_page=1000):
    """
    Fetch ALL records from Knack with automatic pagination
    Handles 1000+ records by fetching all pages
    """
    url = f"https://api.knack.com/v1/objects/{object_key}/records"
    headers = {
        'X-Knack-Application-Id': KNACK_APP_ID,
        'X-Knack-REST-API-KEY': KNACK_API_KEY,
        'Content-Type': 'application/json'
    }
    
    all_records = []
    page = 1
    
    while True:
        params = {'page': page, 'rows_per_page': rows_per_page}
        if filters:
            params['filters'] = json.dumps(filters)
        
        try:
            print(f"   Fetching page {page}...", end=' ')
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()
            data = response.json()
            
            records = data.get('records', [])
            total_pages = data.get('total_pages', 1)
            total_records = data.get('total_records', len(records))
            
            all_records.extend(records)
            print(f"Got {len(records)} records (Total so far: {len(all_records)}/{total_records})")
            
            # Check if we've fetched all pages
            if page >= total_pages:
                break
            
            page += 1
            time.sleep(0.2)  # Small delay between pages
            
        except Exception as e:
            print(f"\n❌ Error fetching page {page}: {e}")
            break
    
    return all_records


# Profile ID to Role Name mapping
PROFILE_TO_ROLE = {
    'profile_6': 'Student',
    'profile_5': 'Staff Admin',
    'profile_7': 'Tutor',
    'profile_18': 'Head of Year',
    'profile_78': 'Subject Teacher'
}

def extract_email_from_html(html_string):
    """Extract clean email from Knack HTML anchor tag"""
    if not html_string:
        return None
    
    # If it's already a clean email, return it
    if '@' in html_string and '<' not in html_string:
        return html_string
    
    # Extract from <a href="mailto:email@example.com">email@example.com</a>
    match = re.search(r'mailto:([^"]+)', html_string)
    if match:
        return match.group(1)
    
    # Extract from >email@example.com<
    match = re.search(r'>([^<]+@[^<]+)<', html_string)
    if match:
        return match.group(1)
    
    return html_string

def normalize_account_type(raw_value):
    """Normalize legacy account types"""
    if not raw_value or raw_value.strip() == '':
        return None
    
    raw_upper = raw_value.upper().strip()
    
    if any(keyword in raw_upper for keyword in ['COACHING', 'GOLD', 'SILVER', 'BRONZE']):
        return 'COACHING PORTAL'
    if 'RESOURCE' in raw_upper:
        return 'RESOURCE PORTAL'
    if raw_upper in ['COACHING PORTAL', 'RESOURCE PORTAL']:
        return raw_value
    
    return raw_value


def extract_name_parts(name_field):
    """Extract name components - handles both string and object formats"""
    if not name_field:
        return {'title': None, 'first': None, 'last': None, 'full': None}
    
    # Handle if name_field is a string (some Knack accounts return string)
    if isinstance(name_field, str):
        # Try to split "Mr John Smith" or "John Smith"
        parts = name_field.strip().split()
        if len(parts) >= 2:
            # Check if first part is title
            titles = ['Mr', 'Mrs', 'Ms', 'Dr', 'Miss', 'Prof', 'Sir', 'Dame']
            if parts[0] in titles:
                return {
                    'title': parts[0],
                    'first': parts[1] if len(parts) > 1 else '',
                    'last': ' '.join(parts[2:]) if len(parts) > 2 else '',
                    'full': name_field
                }
            else:
                return {
                    'title': None,
                    'first': parts[0],
                    'last': ' '.join(parts[1:]),
                    'full': name_field
                }
        else:
            return {'title': None, 'first': name_field, 'last': '', 'full': name_field}
    
    # Handle object format (standard Knack person field)
    title = name_field.get('title')
    first = name_field.get('first', '')
    last = name_field.get('last', '')
    full = name_field.get('full') or f"{title or ''} {first} {last}".strip()
    
    return {'title': title, 'first': first, 'last': last, 'full': full}


def batch_insert(table_name, records, batch_size=BATCH_SIZE):
    """
    Insert records in batches to avoid rate limits
    Returns: (success_count, error_count)
    """
    total = len(records)
    success = 0
    errors = 0
    
    for i in range(0, total, batch_size):
        batch = records[i:i+batch_size]
        batch_num = (i // batch_size) + 1
        total_batches = (total + batch_size - 1) // batch_size
        
        try:
            print(f"   Batch {batch_num}/{total_batches}: Inserting {len(batch)} records...", end=' ')
            result = supabase.table(table_name).insert(batch).execute()
            success += len(batch)
            print(f"✅ {len(batch)} inserted")
            
            # Rate limiting
            if i + batch_size < total:
                time.sleep(RATE_LIMIT_DELAY)
                
        except Exception as e:
            print(f"❌ Error: {e}")
            errors += len(batch)
    
    return success, errors


def migrate_accounts_from_object3():
    """Phase 1: Import accounts from Object_3"""
    print("=" * 80)
    print("📚 PHASE 1: Importing Accounts from Object_3")
    print("=" * 80)
    
    # Filter ONLY by establishment (include ALL accounts - even dummy/deleted for test)
    # This should match Knack Builder's 642 accounts
    filters = {
        'match': 'and',
        'rules': [
            {'field': 'field_122', 'operator': 'is', 'value': VESPA_ACADEMY_KNACK_ID}
        ]
    }
    
    print("Fetching accounts from Knack Object_3...")
    accounts = get_knack_records('object_3', filters=filters)
    print(f"✅ Total accounts fetched: {len(accounts)}\n")
    
    if not accounts:
        print("⚠️  No accounts found!")
        return {}
    
    # Prepare batches
    students_to_insert = []
    staff_to_insert = []
    roles_to_assign = []  # Store role assignments for AFTER batch insert
    
    stats = {
        'total': len(accounts),
        'students': 0,
        'staff': 0,
        'multi_role': 0,
        'skipped': 0,
        'flagged': []
    }
    
    # Track specific accounts we care about
    tracked_emails = ['lucas@vespa.academy', 'tut16@vespa.academy', 'tut7@vespa.academy']
    
    print("Processing accounts...")
    for idx, account in enumerate(accounts, 1):
        if idx % 50 == 0:
            print(f"   Processed {idx}/{len(accounts)}...")
        
        try:
            # Extract using _raw fields (Knack API best practice)
            email_raw = account.get('field_70_raw', {})
            email = email_raw.get('email') if isinstance(email_raw, dict) else account.get('field_70')
            
            if not email:
                stats['skipped'] += 1
                continue
            
            # TRACK specific accounts
            if email in tracked_emails:
                print(f"\n   🔍 TRACKING [{email}]:")
                print(f"      Raw email: {email_raw}")
                print(f"      Extracted: {email}")
            
            # Get profile IDs and map to role names
            profile_ids = account.get('field_73_raw', [])
            roles = [PROFILE_TO_ROLE.get(pid, pid) for pid in profile_ids]
            
            # Extract name from _raw field
            name_raw = account.get('field_69_raw', {})
            if isinstance(name_raw, dict):
                name_parts = {
                    'title': name_raw.get('title', ''),
                    'first': name_raw.get('first', ''),
                    'last': name_raw.get('last', ''),
                    'full': name_raw.get('full', '')
                }
            else:
                # Fallback to string parsing
                name_parts = extract_name_parts(account.get('field_69'))
            account_type_raw = account.get('field_441')
            account_type = normalize_account_type(account_type_raw)
            
            if not account_type:
                stats['flagged'].append({
                    'email': email,
                    'reason': 'missing_account_type',
                    'raw': account_type_raw
                })
                account_type = 'COACHING PORTAL'
            
            is_student = 'Student' in roles
            is_staff = any(r in ['Staff Admin', 'Tutor', 'Head of Year', 'Subject Teacher',
                                 'Head of Department', 'General Staff'] for r in roles)
            
            # Check if emulated student (staff in student mode)
            student_group = account.get('field_708', '')
            is_emulated = (student_group == 'EMULATED')
            
            # DEBUG: Print roles for first 10 accounts
            if idx <= 10:
                print(f"   DEBUG [{email}]: roles={roles}, is_student={is_student}, is_staff={is_staff}, emulated={is_emulated}")
            
            # TRACK specific accounts
            if email in tracked_emails:
                print(f"      Roles: {roles}")
                print(f"      Profile IDs: {profile_ids}")
                print(f"      is_student: {is_student}, is_staff: {is_staff}")
            
            if is_student and is_staff:
                stats['multi_role'] += 1
            
            knack_attrs = {
                'id': account.get('id'),
                'email': email,
                'roles': roles,
                'profile_ids': profile_ids,
                'account_type': account_type_raw
            }
            
            # Use RPC for account creation (handles conflicts)
            # STAFF takes precedence for multi-role (Staff + Student)
            if is_staff:
                account_type_for_creation = 'staff'
            elif is_student:
                account_type_for_creation = 'student'
            else:
                stats['skipped'] += 1
                continue
            
            account_result = supabase.rpc('get_or_create_account', {
                'email_param': email,
                'account_type_param': account_type_for_creation,
                'knack_attributes': knack_attrs  # Already a dict
            }).execute()
            
            account_id = account_result.data
            
            # For VESPA ACADEMY test, use hardcoded UUID
            # (In full migration, we'd look up establishments by Knack ID)
            establishment_id = VESPA_ACADEMY_ID  # Supabase UUID
            establishment_name = 'VESPA ACADEMY'
            
            # Update account with full data
            supabase.table('vespa_accounts').update({
                'first_name': name_parts['first'],
                'last_name': name_parts['last'],
                'full_name': name_parts['full'],
                'school_id': establishment_id,
                'school_name': establishment_name,
                'preferences': {
                    'language': account.get('field_2251', 'en'),
                    'notifications_enabled': True
                }
            }).eq('id', account_id).execute()
            
            # Check if student exists first
            if is_student:
                existing_student = supabase.table('vespa_students')\
                    .select('id').eq('email', email).execute()
                
                if not existing_student.data:
                    students_to_insert.append({
                        'email': email,
                        'account_id': account_id,
                        'school_id': establishment_id,
                        'school_name': establishment_name,
                        'current_knack_id': account.get('id'),
                        'first_name': name_parts['first'],
                        'last_name': name_parts['last'],
                        'full_name': name_parts['full'],
                        'current_year_group': account.get('field_550'),
                        'student_group': account.get('field_708'),
                        'current_academic_year': '2025/2026',
                        'current_level': 'Level 2',
                        'current_cycle': 1,
                        'status': 'active',
                        'is_active': True,
                        'sis_student_id': account.get('field_3129'),
                        'knack_user_attributes': knack_attrs,
                        'last_synced_from_knack': datetime.now().isoformat()
                    })
                    stats['students'] += 1
            
            # Check if staff exists first
            if is_staff:
                if email in tracked_emails:
                    print(f"      ✅ is_staff=True, checking if exists...")
                
                existing_staff = supabase.table('vespa_staff')\
                    .select('id').eq('email', email).execute()
                
                if email in tracked_emails:
                    print(f"      Existing staff check: {len(existing_staff.data)} found")
                
                if not existing_staff.data:
                    if email in tracked_emails:
                        print(f"      ➕ Adding to staff_to_insert")
                    
                    staff_to_insert.append({
                        'email': email,
                        'account_id': account_id,
                        'school_id': establishment_id,
                        'school_name': establishment_name,
                        'department': account.get('field_551'),
                        'position_title': name_parts['title'],
                        'active_academic_year': '2025/2026'
                    })
                    stats['staff'] += 1
                    
                    # Collect roles to assign AFTER batch insert
                    for role in roles:
                        role_type = None
                        role_data = {}
                        
                        if role == 'Staff Admin':
                            role_type = 'staff_admin'
                            role_data = {'admin_level': 'full'}
                        elif role == 'Tutor':
                            role_type = 'tutor'
                            role_data = {
                                'tutor_group': account.get('field_708'),
                                'year_group': account.get('field_550')
                            }
                        elif role == 'Head of Year':
                            role_type = 'head_of_year'
                            role_data = {'year_group': account.get('field_550')}
                        elif role == 'Subject Teacher':
                            role_type = 'subject_teacher'
                            role_data = {
                                'subject': account.get('field_551'),
                                'subject_code': account.get('field_2178'),
                                'teaching_group': account.get('field_129')
                            }
                        elif role == 'General Staff':
                            role_type = 'general_staff'
                            role_data = {'access_level': 'view_only'}
                        elif role == 'Head of Department':
                            role_type = 'head_of_department'
                            role_data = {'department': account.get('field_551')}
                        
                        if role_type:
                            roles_to_assign.append({
                                'email': email,
                                'role_type': role_type,
                                'role_data': role_data,
                                'is_primary': len([r for r in roles if r != 'Student']) == 1
                            })
                else:
                    if email in tracked_emails:
                        print(f"      ⏭️  Already exists, skipping")
        
        except Exception as e:
            print(f"❌ Error processing {account.get('field_70', 'unknown')}: {e}")
            continue
    
    # Batch insert students
    if students_to_insert:
        print(f"\n📥 Batch inserting {len(students_to_insert)} students...")
        success, errors = batch_insert('vespa_students', students_to_insert)
        print(f"✅ Students inserted: {success}, Errors: {errors}")
    
    # Batch insert staff
    if staff_to_insert:
        print(f"\n📥 Batch inserting {len(staff_to_insert)} staff...")
        success, errors = batch_insert('vespa_staff', staff_to_insert)
        print(f"✅ Staff inserted: {success}, Errors: {errors}")
    
    # Assign roles AFTER staff are inserted
    if roles_to_assign:
        print(f"\n📋 Assigning {len(roles_to_assign)} roles to staff...")
        roles_assigned = 0
        role_errors = 0
        
        for idx, role_assignment in enumerate(roles_to_assign, 1):
            if idx % 50 == 0:
                print(f"   Assigned {idx}/{len(roles_to_assign)} roles...")
            
            try:
                supabase.rpc('assign_staff_role', {
                    'email_param': role_assignment['email'],
                    'role_type_param': role_assignment['role_type'],
                    'role_data_param': role_assignment['role_data'],
                    'is_primary_param': role_assignment['is_primary']
                }).execute()
                roles_assigned += 1
                
                # Small delay every 50 roles
                if idx % 50 == 0:
                    time.sleep(0.1)
                    
            except Exception as e:
                print(f"   ❌ Error assigning {role_assignment['role_type']} to {role_assignment['email']}: {e}")
                role_errors += 1
        
        print(f"✅ Roles assigned: {roles_assigned}, Errors: {role_errors}")
    
    return stats


def batch_insert(table_name, records, batch_size=BATCH_SIZE):
    """Insert records in batches"""
    total = len(records)
    success = 0
    errors = 0
    
    for i in range(0, total, batch_size):
        batch = records[i:i+batch_size]
        batch_num = (i // batch_size) + 1
        total_batches = (total + batch_size - 1) // batch_size
        
        try:
            print(f"   Batch {batch_num}/{total_batches} ({len(batch)} records)...", end=' ')
            result = supabase.table(table_name).insert(batch).execute()
            success += len(batch)
            print(f"✅")
            
            # Rate limiting
            if i + batch_size < total:
                time.sleep(RATE_LIMIT_DELAY)
                
        except Exception as e:
            # Try individual inserts for failed batch
            print(f"⚠️  Batch failed, trying individual inserts...")
            for record in batch:
                try:
                    supabase.table(table_name).insert(record).execute()
                    success += 1
                except Exception as individual_error:
                    print(f"      ❌ {record.get('email', 'unknown')}: {individual_error}")
                    errors += 1
    
    return success, errors


def build_connections_from_object6():
    """
    Phase 2: Build connections from Object_6
    Uses batch processing for connection creation
    """
    print("\n" + "=" * 80)
    print("🔗 PHASE 2: Building Connections from Object_6")
    print("=" * 80)
    
    filters = {
        'match': 'and',
        'rules': [
            {'field': 'field_179', 'operator': 'is', 'value': VESPA_ACADEMY_KNACK_ID}
        ]
    }
    
    print("Fetching students from Object_6...")
    students = get_knack_records('object_6', filters=filters)
    print(f"✅ Total students fetched: {len(students)}\n")
    
    # Get all account IDs upfront (for faster lookups)
    print("Loading account mappings...")
    all_accounts = supabase.table('vespa_accounts')\
        .select('id, email').eq('school_id', VESPA_ACADEMY_ID).execute()
    
    account_map = {acc['email']: acc['id'] for acc in all_accounts.data}
    print(f"✅ Loaded {len(account_map)} account mappings\n")
    
    connections_to_create = []
    stats = {
        'tutor': 0,
        'head_of_year': 0,
        'subject_teacher': 0,
        'staff_admin': 0,
        'errors': 0
    }
    
    print("Processing connections...")
    debug_count = 0
    for idx, student in enumerate(students, 1):
        if idx % 100 == 0:
            print(f"   Processed {idx}/{len(students)} students...")
        
        try:
            # Extract student email from _raw field
            student_email_raw = student.get('field_91_raw', {})
            if isinstance(student_email_raw, dict):
                student_email = student_email_raw.get('email')
            else:
                # Fallback: Extract from HTML if needed
                student_email = extract_email_from_html(student.get('field_91', ''))
            
            if not student_email or student_email not in account_map:
                continue
            
            student_account_id = account_map[student_email]
            
            # Extract connection arrays from _raw fields
            staff_admins_raw = student.get('field_190_raw', [])
            tutors_raw = student.get('field_1682_raw', [])
            hoys_raw = student.get('field_547_raw', [])
            teachers_raw = student.get('field_2177_raw', [])
            
            # DEBUG: Show first 5 students with connections
            if debug_count < 5 and any([staff_admins_raw, tutors_raw, hoys_raw, teachers_raw]):
                print(f"\n   DEBUG Student: {student_email}")
                print(f"      Staff Admins: {staff_admins_raw}")
                print(f"      Tutors: {tutors_raw}")
                print(f"      HOYs: {hoys_raw}")
                print(f"      Teachers: {teachers_raw}")
                debug_count += 1
            
            # Build connection list from _raw arrays
            # _raw format: [{"id": "record_id", "identifier": "<a href='mailto:email'>email</a>"}]
            # Need to extract clean email from HTML!
            for staff in staff_admins_raw:
                if isinstance(staff, dict):
                    staff_email_html = staff.get('identifier')
                    staff_email = extract_email_from_html(staff_email_html)
                    if staff_email and staff_email in account_map:
                        connections_to_create.append({
                            'staff_email': staff_email,
                            'student_email': student_email,
                            'type': 'staff_admin'
                        })
                        stats['staff_admin'] += 1
            
            for tutor in tutors_raw:
                if isinstance(tutor, dict):
                    tutor_email_html = tutor.get('identifier')
                    tutor_email = extract_email_from_html(tutor_email_html)
                    if tutor_email and tutor_email in account_map:
                        connections_to_create.append({
                            'staff_email': tutor_email,
                            'student_email': student_email,
                            'type': 'tutor'
                        })
                        stats['tutor'] += 1
            
            for hoy in hoys_raw:
                if isinstance(hoy, dict):
                    hoy_email_html = hoy.get('identifier')
                    hoy_email = extract_email_from_html(hoy_email_html)
                    if hoy_email and hoy_email in account_map:
                        connections_to_create.append({
                            'staff_email': hoy_email,
                            'student_email': student_email,
                            'type': 'head_of_year'
                        })
                        stats['head_of_year'] += 1
            
            for teacher in teachers_raw:
                if isinstance(teacher, dict):
                    teacher_email_html = teacher.get('identifier')
                    teacher_email = extract_email_from_html(teacher_email_html)
                    if teacher_email and teacher_email in account_map:
                        connections_to_create.append({
                            'staff_email': teacher_email,
                            'student_email': student_email,
                            'type': 'subject_teacher'
                        })
                        stats['subject_teacher'] += 1
        
        except Exception as e:
            stats['errors'] += 1
            continue
    
    # Create connections using RPC (handles duplicates)
    print(f"\n📥 Creating {len(connections_to_create)} connections...")
    created = 0
    for idx, conn in enumerate(connections_to_create, 1):
        if idx % 100 == 0:
            print(f"   Created {idx}/{len(connections_to_create)}...")
        
        try:
            supabase.rpc('create_staff_student_connection', {
                'staff_email_param': conn['staff_email'],
                'student_email_param': conn['student_email'],
                'connection_type_param': conn['type'],
                'context_param': {}
            }).execute()
            created += 1
            
            # Small delay every 50 connections
            if idx % 50 == 0:
                time.sleep(0.1)
                
        except Exception as e:
            if 'not found' in str(e).lower():
                pass  # Staff not yet created, skip
            else:
                print(f"⚠️  Error: {conn['staff_email']} → {conn['student_email']}: {e}")
    
    print(f"✅ Created {created}/{len(connections_to_create)} connections")
    
    return stats


def verify_migration():
    """Verification checks"""
    print("\n" + "=" * 80)
    print("🔍 VERIFICATION")
    print("=" * 80)
    
    # Accounts
    accounts = supabase.table('vespa_accounts')\
        .select('account_type').eq('school_id', VESPA_ACADEMY_ID).execute()
    
    student_count = len([a for a in accounts.data if a['account_type'] == 'student'])
    staff_count = len([a for a in accounts.data if a['account_type'] == 'staff'])
    
    print(f"✅ vespa_accounts: {len(accounts.data)} total")
    print(f"   - Students: {student_count}")
    print(f"   - Staff: {staff_count}")
    
    # Students
    students = supabase.table('vespa_students')\
        .select('id').eq('school_id', VESPA_ACADEMY_ID).execute()
    print(f"✅ vespa_students: {len(students.data)}")
    
    # Staff
    staff = supabase.table('vespa_staff')\
        .select('id').eq('school_id', VESPA_ACADEMY_ID).execute()
    print(f"✅ vespa_staff: {len(staff.data)}")
    
    # Roles
    all_roles = supabase.table('user_roles').select('role_type').execute()
    print(f"✅ user_roles: {len(all_roles.data)}")
    
    # Connections  
    connections = supabase.table('user_connections').select('connection_type').execute()
    print(f"✅ user_connections: {len(connections.data)}")
    
    if connections.data:
        conn_counts = {}
        for c in connections.data:
            conn_type = c['connection_type']
            conn_counts[conn_type] = conn_counts.get(conn_type, 0) + 1
        for conn_type, count in sorted(conn_counts.items()):
            print(f"   - {conn_type}: {count}")


def main():
    """Main migration"""
    try:
        # Phase 1
        account_stats = migrate_accounts_from_object3()
        
        print(f"\n📊 Phase 1 Complete:")
        print(f"  Accounts: {account_stats['total']}")
        print(f"  Students: {account_stats['students']}")
        print(f"  Staff: {account_stats['staff']}")
        print(f"  Multi-role: {account_stats['multi_role']}")
        
        if account_stats['flagged']:
            print(f"\n⚠️  {len(account_stats['flagged'])} flagged for review")
        
        # Phase 2
        connection_stats = build_connections_from_object6()
        
        print(f"\n📊 Phase 2 Complete:")
        print(f"  Tutor connections: {connection_stats['tutor']}")
        print(f"  HOY connections: {connection_stats['head_of_year']}")
        print(f"  Teacher connections: {connection_stats['subject_teacher']}")
        print(f"  Staff Admin connections: {connection_stats['staff_admin']}")
        
        # Verify
        verify_migration()
        
        print("\n" + "=" * 80)
        print("✅ VESPA ACADEMY MIGRATION COMPLETE!")
        print("=" * 80)
        
    except Exception as e:
        print(f"\n❌ Failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()

