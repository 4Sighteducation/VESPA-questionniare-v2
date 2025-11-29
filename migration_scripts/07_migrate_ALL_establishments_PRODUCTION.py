"""
PRODUCTION Migration: All Establishments (Except VESPA ACADEMY)
Purpose: Migrate all 127 schools (~24,000 accounts) to Supabase
Version: PRODUCTION v1.0
Features:
- Processes all establishments
- Excludes VESPA ACADEMY (already migrated)
- Clean logs (no debug spam)
- Progress tracking
- Error logging to file
- Safe for overnight run
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
KNACK_APP_ID = os.getenv('KNACK_APP_ID')
KNACK_API_KEY = os.getenv('KNACK_API_KEY')

# VESPA ACADEMY - Already migrated, exclude
VESPA_ACADEMY_KNACK_ID = '603e9f97cb8481001b31183d'

# Batch settings
BATCH_SIZE = 100
RATE_LIMIT_DELAY = 0.5

# Error logging
ERROR_LOG_FILE = Path(__file__).parent / f'migration_errors_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'

print("=" * 80)
print("🚀 PRODUCTION MIGRATION: All Establishments")
print("=" * 80)
print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print(f"Supabase: {SUPABASE_URL}")
print(f"Batch size: {BATCH_SIZE}")
print(f"Error log: {ERROR_LOG_FILE}")
print()

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
print("✅ Supabase connected\n")


def log_error(message):
    """Log errors to file"""
    with open(ERROR_LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(f"[{datetime.now()}] {message}\n")


# Profile ID to Role Name mapping
PROFILE_TO_ROLE = {
    'profile_6': 'Student',
    'profile_5': 'Staff Admin',
    'profile_7': 'Tutor',
    'profile_18': 'Head of Year',
    'profile_78': 'Subject Teacher'
}


def extract_email_from_html(html_string):
    """Extract clean email from HTML"""
    if not html_string:
        return None
    if '@' in html_string and '<' not in html_string:
        return html_string
    match = re.search(r'mailto:([^"]+)', html_string)
    if match:
        return match.group(1)
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


def get_knack_records(object_key, filters=None, rows_per_page=1000):
    """Fetch ALL records with pagination"""
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
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()
            data = response.json()
            
            records = data.get('records', [])
            total_pages = data.get('total_pages', 1)
            all_records.extend(records)
            
            if page >= total_pages:
                break
            page += 1
            time.sleep(0.2)
        except Exception as e:
            log_error(f"Error fetching {object_key} page {page}: {e}")
            break
    
    return all_records


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
            supabase.table(table_name).insert(batch).execute()
            success += len(batch)
            print(f"      Batch {batch_num}/{total_batches}: ✅")
            
            if i + batch_size < total:
                time.sleep(RATE_LIMIT_DELAY)
        except Exception as e:
            log_error(f"Batch insert error in {table_name}: {e}")
            print(f"      Batch {batch_num}/{total_batches}: ⚠️ Error (see log)")
            errors += len(batch)
    
    return success, errors


def migrate_establishment(establishment):
    """Migrate a single establishment"""
    est_id = establishment['id']
    est_knack_id = establishment['knack_id']
    est_name = establishment['name']
    
    print("\n" + "=" * 80)
    print(f"🏫 {est_name}")
    print("=" * 80)
    
    # Skip VESPA ACADEMY (already migrated)
    if est_knack_id == VESPA_ACADEMY_KNACK_ID:
        print("⏭️  Already migrated, skipping")
        return {'skipped': True}
    
    stats = {
        'establishment_name': est_name,
        'accounts_fetched': 0,
        'students_created': 0,
        'staff_created': 0,
        'roles_assigned': 0,
        'connections_created': 0,
        'multi_role': 0,
        'errors': 0
    }
    
    # Phase 1: Import accounts from Object_3
    print(f"📥 Fetching accounts from Object_3...")
    filters = {
        'match': 'and',
        'rules': [
            {'field': 'field_122', 'operator': 'is', 'value': est_knack_id}
        ]
    }
    
    accounts = get_knack_records('object_3', filters=filters)
    stats['accounts_fetched'] = len(accounts)
    print(f"   Found {len(accounts)} accounts")
    
    if not accounts:
        print("   No accounts found, skipping")
        return stats
    
    # Prepare batches
    students_to_insert = []
    staff_to_insert = []
    roles_to_assign = []
    
    print(f"📝 Processing accounts...")
    for idx, account in enumerate(accounts, 1):
        if idx % 100 == 0:
            print(f"   {idx}/{len(accounts)}...")
        
        try:
            # Extract data using _raw fields
            email_raw = account.get('field_70_raw', {})
            email = email_raw.get('email') if isinstance(email_raw, dict) else account.get('field_70')
            
            if not email:
                continue
            
            # Get roles
            profile_ids = account.get('field_73_raw', [])
            roles = [PROFILE_TO_ROLE.get(pid, pid) for pid in profile_ids]
            
            # Extract name
            name_raw = account.get('field_69_raw', {})
            if isinstance(name_raw, dict):
                full_name = name_raw.get('full', '')
                first_name = name_raw.get('first', '')
                last_name = name_raw.get('last', '')
                title = name_raw.get('title', '')
                
                # Clean establishment name from full name if present
                # Some Knack records have "School Name First Last" format
                if est_name in full_name:
                    full_name = full_name.replace(est_name, '').strip()
                
                # Rebuild if needed
                if not full_name and (first_name or last_name):
                    full_name = f"{title} {first_name} {last_name}".strip()
                
                name_parts = {
                    'title': title,
                    'first': first_name,
                    'last': last_name,
                    'full': full_name
                }
            else:
                full = str(name_raw) if name_raw else ''
                # Clean establishment name
                if est_name in full:
                    full = full.replace(est_name, '').strip()
                parts = full.split()
                name_parts = {
                    'title': '',
                    'first': parts[0] if parts else '',
                    'last': ' '.join(parts[1:]) if len(parts) > 1 else '',
                    'full': full
                }
            
            account_type_raw = account.get('field_441')
            account_type = normalize_account_type(account_type_raw)
            
            if not account_type:
                account_type = 'COACHING PORTAL'
            
            is_student = 'Student' in roles
            is_staff = any(r in ['Staff Admin', 'Tutor', 'Head of Year', 'Subject Teacher',
                                 'Head of Department', 'General Staff'] for r in roles)
            
            if is_student and is_staff:
                stats['multi_role'] += 1
            
            # Staff takes precedence
            if is_staff:
                account_type_for_creation = 'staff'
            elif is_student:
                account_type_for_creation = 'student'
            else:
                continue
            
            knack_attrs = {
                'id': account.get('id'),
                'email': email,
                'roles': roles,
                'profile_ids': profile_ids,
                'account_type': account_type_raw
            }
            
            # Create account
            account_result = supabase.rpc('get_or_create_account', {
                'email_param': email,
                'account_type_param': account_type_for_creation,
                'knack_attributes': knack_attrs
            }).execute()
            
            account_id = account_result.data
            
            # Update with full data
            supabase.table('vespa_accounts').update({
                'first_name': name_parts['first'],
                'last_name': name_parts['last'],
                'full_name': name_parts['full'],
                'school_id': est_id,
                'school_name': est_name,
                'preferences': {
                    'language': account.get('field_2251', 'en'),
                    'notifications_enabled': True
                }
            }).eq('id', account_id).execute()
            
            # Add to student batch
            if is_student:
                existing = supabase.table('vespa_students')\
                    .select('id').eq('email', email).execute()
                
                if not existing.data:
                    students_to_insert.append({
                        'email': email,
                        'account_id': account_id,
                        'school_id': est_id,
                        'school_name': est_name,
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
            
            # Add to staff batch
            if is_staff:
                existing = supabase.table('vespa_staff')\
                    .select('id').eq('email', email).execute()
                
                if not existing.data:
                    staff_to_insert.append({
                        'email': email,
                        'account_id': account_id,
                        'school_id': est_id,
                        'school_name': est_name,
                        'department': account.get('field_551'),
                        'position_title': name_parts['title'],
                        'active_academic_year': '2025/2026'
                    })
                    
                    # Collect roles for later assignment
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
        
        except Exception as e:
            log_error(f"{est_name} - Error processing {account.get('field_70', 'unknown')}: {e}")
            stats['errors'] += 1
            continue
    
    # Batch insert students
    if students_to_insert:
        print(f"👥 Inserting {len(students_to_insert)} students...")
        success, errors = batch_insert('vespa_students', students_to_insert)
        stats['students_created'] = success
        if errors > 0:
            log_error(f"{est_name} - {errors} student insert errors")
    
    # Batch insert staff
    if staff_to_insert:
        print(f"👨‍🏫 Inserting {len(staff_to_insert)} staff...")
        success, errors = batch_insert('vespa_staff', staff_to_insert)
        stats['staff_created'] = success
        if errors > 0:
            log_error(f"{est_name} - {errors} staff insert errors")
    
    # Assign roles
    if roles_to_assign:
        print(f"🎭 Assigning {len(roles_to_assign)} roles...")
        for idx, role_assignment in enumerate(roles_to_assign, 1):
            try:
                supabase.rpc('assign_staff_role', {
                    'email_param': role_assignment['email'],
                    'role_type_param': role_assignment['role_type'],
                    'role_data_param': role_assignment['role_data'],
                    'is_primary_param': role_assignment['is_primary']
                }).execute()
                stats['roles_assigned'] += 1
                
                if idx % 50 == 0:
                    time.sleep(0.1)
            except Exception as e:
                log_error(f"{est_name} - Role error: {role_assignment['email']} {role_assignment['role_type']}: {e}")
        
        print(f"   ✅ {stats['roles_assigned']} roles assigned")
    
    # Build connections from Object_6
    print(f"🔗 Building connections...")
    filters = {
        'match': 'and',
        'rules': [
            {'field': 'field_179', 'operator': 'is', 'value': est_knack_id}
        ]
    }
    
    students = get_knack_records('object_6', filters=filters)
    
    # Get account mappings
    all_accounts = supabase.table('vespa_accounts')\
        .select('id, email').eq('school_id', est_id).execute()
    account_map = {acc['email']: acc['id'] for acc in all_accounts.data}
    
    connections_to_create = []
    
    for student in students:
        try:
            student_email_raw = student.get('field_91_raw', {})
            if isinstance(student_email_raw, dict):
                student_email = student_email_raw.get('email')
            else:
                student_email = extract_email_from_html(student.get('field_91', ''))
            
            if not student_email or student_email not in account_map:
                continue
            
            # Extract connections from _raw fields
            staff_admins_raw = student.get('field_190_raw', [])
            tutors_raw = student.get('field_1682_raw', [])
            hoys_raw = student.get('field_547_raw', [])
            teachers_raw = student.get('field_2177_raw', [])
            
            # Build connection list
            for staff in staff_admins_raw:
                if isinstance(staff, dict):
                    staff_email = extract_email_from_html(staff.get('identifier'))
                    if staff_email and staff_email in account_map:
                        connections_to_create.append({
                            'staff_email': staff_email,
                            'student_email': student_email,
                            'type': 'staff_admin'
                        })
            
            for tutor in tutors_raw:
                if isinstance(tutor, dict):
                    tutor_email = extract_email_from_html(tutor.get('identifier'))
                    if tutor_email and tutor_email in account_map:
                        connections_to_create.append({
                            'staff_email': tutor_email,
                            'student_email': student_email,
                            'type': 'tutor'
                        })
            
            for hoy in hoys_raw:
                if isinstance(hoy, dict):
                    hoy_email = extract_email_from_html(hoy.get('identifier'))
                    if hoy_email and hoy_email in account_map:
                        connections_to_create.append({
                            'staff_email': hoy_email,
                            'student_email': student_email,
                            'type': 'head_of_year'
                        })
            
            for teacher in teachers_raw:
                if isinstance(teacher, dict):
                    teacher_email = extract_email_from_html(teacher.get('identifier'))
                    if teacher_email and teacher_email in account_map:
                        connections_to_create.append({
                            'staff_email': teacher_email,
                            'student_email': student_email,
                            'type': 'subject_teacher'
                        })
        except Exception as e:
            log_error(f"{est_name} - Connection processing error: {e}")
            continue
    
    # Create connections
    if connections_to_create:
        print(f"   Creating {len(connections_to_create)} connections...")
        created = 0
        for conn in connections_to_create:
            try:
                supabase.rpc('create_staff_student_connection', {
                    'staff_email_param': conn['staff_email'],
                    'student_email_param': conn['student_email'],
                    'connection_type_param': conn['type'],
                    'context_param': {}
                }).execute()
                created += 1
                
                if created % 100 == 0:
                    print(f"      {created}/{len(connections_to_create)}...")
                    time.sleep(0.1)
            except Exception as e:
                log_error(f"{est_name} - Connection error: {conn['staff_email']} → {conn['student_email']}: {e}")
        
        stats['connections_created'] = created
        print(f"   ✅ {created} connections created")
    
    return stats


def main():
    """Main migration orchestrator"""
    start_time = datetime.now()
    
    # Get all establishments
    print("📊 Fetching establishments...")
    establishments = supabase.table('establishments')\
        .select('id, knack_id, name')\
        .eq('status', 'Active')\
        .order('name')\
        .execute()
    
    total_establishments = len(establishments.data)
    print(f"✅ Found {total_establishments} active establishments")
    
    # Exclude VESPA ACADEMY
    to_migrate = [e for e in establishments.data if e['knack_id'] != VESPA_ACADEMY_KNACK_ID]
    print(f"   Excluding VESPA ACADEMY (already migrated)")
    print(f"   {len(to_migrate)} establishments to migrate")
    print()
    
    # Overall stats
    overall_stats = {
        'establishments_processed': 0,
        'establishments_skipped': 0,
        'total_accounts': 0,
        'total_students': 0,
        'total_staff': 0,
        'total_roles': 0,
        'total_connections': 0,
        'total_errors': 0
    }
    
    # Migrate each establishment
    for idx, establishment in enumerate(to_migrate, 1):
        print(f"\n[{idx}/{len(to_migrate)}]")
        
        try:
            result = migrate_establishment(establishment)
            
            if result.get('skipped'):
                overall_stats['establishments_skipped'] += 1
            else:
                overall_stats['establishments_processed'] += 1
                overall_stats['total_accounts'] += result.get('accounts_fetched', 0)
                overall_stats['total_students'] += result.get('students_created', 0)
                overall_stats['total_staff'] += result.get('staff_created', 0)
                overall_stats['total_roles'] += result.get('roles_assigned', 0)
                overall_stats['total_connections'] += result.get('connections_created', 0)
                overall_stats['total_errors'] += result.get('errors', 0)
                
                # Summary for this establishment
                print(f"   ✅ Complete: {result['students_created']} students, "
                      f"{result['staff_created']} staff, "
                      f"{result['roles_assigned']} roles, "
                      f"{result['connections_created']} connections")
            
        except Exception as e:
            log_error(f"CRITICAL - Failed to process {establishment['name']}: {e}")
            print(f"   ❌ Error (see log)")
            overall_stats['establishments_skipped'] += 1
    
    # Final summary
    end_time = datetime.now()
    duration = end_time - start_time
    
    print("\n" + "=" * 80)
    print("✅ PRODUCTION MIGRATION COMPLETE!")
    print("=" * 80)
    print(f"Started:  {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Finished: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Duration: {duration}")
    print()
    print(f"📊 Summary:")
    print(f"   Establishments processed: {overall_stats['establishments_processed']}")
    print(f"   Establishments skipped: {overall_stats['establishments_skipped']}")
    print(f"   Total accounts: {overall_stats['total_accounts']}")
    print(f"   Students created: {overall_stats['total_students']}")
    print(f"   Staff created: {overall_stats['total_staff']}")
    print(f"   Roles assigned: {overall_stats['total_roles']}")
    print(f"   Connections created: {overall_stats['total_connections']}")
    print(f"   Errors logged: {overall_stats['total_errors']}")
    print()
    
    if overall_stats['total_errors'] > 0:
        print(f"⚠️  Check error log: {ERROR_LOG_FILE}")
    
    print("=" * 80)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Migration interrupted by user")
        print(f"Check error log for details: {ERROR_LOG_FILE}")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Critical error: {e}")
        log_error(f"CRITICAL ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

