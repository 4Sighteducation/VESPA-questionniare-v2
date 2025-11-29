# Supabase Account Schema Reference

**Purpose**: Complete field reference for upload system dual-write integration  
**Date**: November 2025  
**Status**: Production Ready

---

## 🔑 **vespa_accounts (Parent Table for ALL Users)**

### **Purpose**: Unified authentication layer for students and staff

```sql
CREATE TABLE vespa_accounts (
  -- Core Identity
  id UUID PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,  -- PRIMARY IDENTIFIER
  
  -- Authentication
  supabase_user_id UUID,               -- NULL for now (Knack auth)
  auth_provider VARCHAR DEFAULT 'knack',
  password_reset_required BOOLEAN DEFAULT false,
  last_login_at TIMESTAMP,
  login_count INTEGER DEFAULT 0,
  
  -- Knack Bridge
  current_knack_id VARCHAR,            -- Current Knack record ID
  historical_knack_ids TEXT[],         -- Array for year rollovers
  knack_user_attributes JSONB,         -- Full Knack record
  last_synced_from_knack TIMESTAMP,
  
  -- Basic Information
  first_name VARCHAR,
  last_name VARCHAR,
  full_name VARCHAR,
  phone_number VARCHAR,
  avatar_url TEXT,
  
  -- Organization
  school_id UUID,                      -- FK to establishments(id)
  school_name VARCHAR,                 -- Denormalized
  trust_name VARCHAR,
  
  -- Account Status
  account_type VARCHAR NOT NULL,       -- 'student' or 'staff'
  is_active BOOLEAN DEFAULT true,
  status VARCHAR DEFAULT 'active',
  deactivated_at TIMESTAMP,
  deactivated_reason TEXT,
  
  -- Preferences
  preferences JSONB DEFAULT '{"language": "en", "notifications_enabled": true}',
  
  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  created_by VARCHAR DEFAULT 'system',
  deleted_at TIMESTAMP,
  deleted_by VARCHAR
);
```

### **Required Fields for Upload:**

| Field | Required | Source | Notes |
|-------|----------|--------|-------|
| email | ✅ YES | Knack field_70 | Primary identifier |
| account_type | ✅ YES | Derived from roles | 'staff' if ANY staff role, else 'student' |
| first_name | ⚠️ Important | Knack field_69_raw.first | |
| last_name | ⚠️ Important | Knack field_69_raw.last | |
| full_name | ⚠️ Important | Knack field_69_raw.full | Clean school name if present |
| school_id | ✅ YES | Knack field_122 → lookup establishments | UUID |
| school_name | ✅ YES | Knack field_122_raw[0].identifier | For performance |
| current_knack_id | ✅ YES | Knack record.id | Track Knack record |
| knack_user_attributes | ⚠️ Useful | Full Knack record | Store for reference |

---

## 👨‍🎓 **vespa_students (Student Extension)**

### **Purpose**: Student-specific data (extends vespa_accounts)

```sql
CREATE TABLE vespa_students (
  id UUID PRIMARY KEY,
  account_id UUID UNIQUE REFERENCES vespa_accounts(id),  -- Links to parent
  email VARCHAR UNIQUE NOT NULL,                         -- Denormalized
  
  -- School
  school_id UUID REFERENCES establishments(id),
  school_name VARCHAR,
  
  -- Knack
  current_knack_id VARCHAR,
  
  -- Basic Info
  first_name VARCHAR,
  last_name VARCHAR,
  full_name VARCHAR,
  
  -- Academic
  current_year_group VARCHAR,          -- "Year 7", "Year 10", etc.
  student_group VARCHAR,               -- Tutor group / pastoral group
  current_academic_year VARCHAR,       -- "2025/2026"
  current_level VARCHAR,               -- "Level 2", "Level 3"
  current_cycle INTEGER DEFAULT 1,     -- Questionnaire cycle
  
  -- Student ID
  sis_student_id VARCHAR,              -- ULN or student number
  
  -- Activities (Cached)
  total_points INTEGER DEFAULT 0,
  total_activities_completed INTEGER DEFAULT 0,
  total_achievements INTEGER DEFAULT 0,
  current_streak_days INTEGER DEFAULT 0,
  longest_streak_days INTEGER DEFAULT 0,
  last_activity_at TIMESTAMP,
  
  -- VESPA Scores (Cached from vespa_scores table)
  latest_vespa_scores JSONB,
  
  -- Status
  status VARCHAR DEFAULT 'active',
  is_active BOOLEAN DEFAULT true,
  
  -- Year Tracking
  years_in_system INTEGER DEFAULT 1,
  previous_academic_years TEXT[],
  enrollment_date DATE,
  expected_graduation_date DATE,
  
  -- Contact
  phone_number VARCHAR,
  parent_email VARCHAR,
  parent_phone VARCHAR,
  
  -- Preferences
  preferences JSONB DEFAULT '{}',
  
  -- Sync
  last_synced_from_knack TIMESTAMP,
  knack_user_attributes JSONB,
  
  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  created_by VARCHAR DEFAULT 'system',
  deleted_at TIMESTAMP,
  deleted_by VARCHAR
);
```

### **Required Fields for Student Upload:**

| Field | Required | Source | Notes |
|-------|----------|--------|-------|
| email | ✅ YES | Same as vespa_accounts | |
| account_id | ✅ YES | From vespa_accounts.id | |
| school_id | ✅ YES | Same as vespa_accounts | |
| school_name | ✅ YES | Same as vespa_accounts | |
| first_name | ✅ YES | Same as vespa_accounts | |
| last_name | ✅ YES | Same as vespa_accounts | |
| full_name | ✅ YES | Same as vespa_accounts | |
| current_knack_id | ✅ YES | Knack record.id | |
| current_year_group | ⚠️ Important | Knack field_548 or field_550 | |
| student_group | ⚠️ Important | Knack field_708 or field_565 | Tutor/pastoral group |
| current_academic_year | ✅ YES | Current year or field_204 | "2025/2026" |
| sis_student_id | ⚠️ Useful | Knack field_3129 | ULN |

---

## 👨‍🏫 **vespa_staff (Staff Extension)**

### **Purpose**: Staff-specific data (extends vespa_accounts)

```sql
CREATE TABLE vespa_staff (
  id UUID PRIMARY KEY,
  account_id UUID UNIQUE REFERENCES vespa_accounts(id),  -- Links to parent
  email VARCHAR UNIQUE NOT NULL,                         -- Denormalized
  
  -- School
  school_id UUID REFERENCES establishments(id),
  school_name VARCHAR,
  
  -- Employment
  employee_id VARCHAR,
  department VARCHAR,                  -- Subject/department
  position_title VARCHAR,              -- "Mr", "Ms", "Dr" etc.
  employment_start_date DATE,
  employment_end_date DATE,
  
  -- Workload (Cached)
  assigned_students_count INTEGER DEFAULT 0,
  active_academic_year VARCHAR,
  max_student_capacity INTEGER,
  
  -- Activity Stats (Cached)
  total_activities_assigned INTEGER DEFAULT 0,
  total_feedback_given INTEGER DEFAULT 0,
  total_certificates_awarded INTEGER DEFAULT 0,
  last_activity_at TIMESTAMP,
  
  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### **Required Fields for Staff Upload:**

| Field | Required | Source | Notes |
|-------|----------|--------|-------|
| email | ✅ YES | Same as vespa_accounts | |
| account_id | ✅ YES | From vespa_accounts.id | |
| school_id | ✅ YES | Same as vespa_accounts | |
| school_name | ✅ YES | Same as vespa_accounts | |
| department | ⚠️ Useful | Knack field_551 | Subject taught |
| position_title | ⚠️ Useful | Knack field_69_raw.title | "Mr", "Ms", "Dr" |
| active_academic_year | ✅ YES | Current year | "2025/2026" |

---

## 🎭 **user_roles (Multi-Role Support)**

### **Purpose**: One staff member can have multiple roles

```sql
CREATE TABLE user_roles (
  id UUID PRIMARY KEY,
  account_id UUID REFERENCES vespa_accounts(id),
  role_type VARCHAR NOT NULL,
  role_data JSONB DEFAULT '{}',
  is_primary BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  assigned_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### **Role Types:**

| Role Type | Profile ID | Object | Role Data Example |
|-----------|------------|--------|-------------------|
| `student` | profile_6 | object_6 | N/A (not stored in user_roles) |
| `staff_admin` | profile_5 | object_5 | `{"admin_level": "full"}` |
| `tutor` | profile_7 | object_7 | `{"tutor_group": "10A", "year_group": "Year 10"}` |
| `head_of_year` | profile_18 | object_18 | `{"year_group": "Year 10"}` |
| `subject_teacher` | profile_78 | object_78 | `{"subject": "Mathematics", "subject_code": "MA"}` |
| `general_staff` | profile_? | - | `{"access_level": "view_only"}` |
| `head_of_department` | profile_? | - | `{"department": "Science"}` |

### **Required for Upload:**

For each staff role in Knack field_73_raw:
```python
supabase.rpc('assign_staff_role', {
    'email_param': email,
    'role_type_param': role_type,
    'role_data_param': role_data,
    'is_primary_param': is_primary
})
```

---

## 🔗 **user_connections (Relationships)**

### **Purpose**: Staff ↔ Student many-to-many relationships

```sql
CREATE TABLE user_connections (
  id UUID PRIMARY KEY,
  staff_account_id UUID REFERENCES vespa_accounts(id),
  student_account_id UUID REFERENCES vespa_accounts(id),
  connection_type VARCHAR NOT NULL,
  context JSONB DEFAULT '{}',
  synced_from_knack BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### **Connection Types:**

| Connection Type | Source | Stored in Object_6 Field |
|----------------|--------|--------------------------|
| `tutor` | Tutor → Student | field_1682 |
| `head_of_year` | HOY → Student | field_547 |
| `subject_teacher` | Teacher → Student | field_2177 |
| `staff_admin` | Admin → Student | field_190 (optional - RLS handles) |

### **Required for Upload:**

For each student connection in Object_6:
```python
supabase.rpc('create_staff_student_connection', {
    'staff_email_param': staff_email,
    'student_email_param': student_email,
    'connection_type_param': connection_type,
    'context_param': {}
})
```

**Note**: Staff Admin connections are OPTIONAL - RLS gives them establishment-wide access automatically!

---

## 📋 **Upload Flow: New Student**

```python
def create_student_in_supabase(knack_student_data):
    """
    After creating student in Knack, also create in Supabase
    """
    # Step 1: Create vespa_account
    account = supabase.rpc('get_or_create_account', {
        'email_param': student['email'],
        'account_type_param': 'student',
        'knack_attributes': knack_student_data
    }).execute()
    
    account_id = account.data
    
    # Step 2: Update vespa_account with full data
    supabase.table('vespa_accounts').update({
        'first_name': student['first_name'],
        'last_name': student['last_name'],
        'full_name': student['full_name'],
        'school_id': establishment_uuid,
        'school_name': establishment_name,
        'phone_number': student.get('phone')
    }).eq('id', account_id).execute()
    
    # Step 3: Create vespa_students entry
    supabase.table('vespa_students').upsert({
        'email': student['email'],
        'account_id': account_id,
        'school_id': establishment_uuid,
        'school_name': establishment_name,
        'current_knack_id': knack_record_id,
        'first_name': student['first_name'],
        'last_name': student['last_name'],
        'full_name': student['full_name'],
        'current_year_group': student['year_group'],
        'student_group': student['tutor_group'],
        'current_academic_year': '2025/2026',
        'sis_student_id': student.get('uln'),
        'knack_user_attributes': knack_student_data,
        'last_synced_from_knack': datetime.now()
    }, on_conflict='email').execute()
```

---

## 📋 **Upload Flow: New Staff**

```python
def create_staff_in_supabase(knack_staff_data):
    """
    After creating staff in Knack, also create in Supabase
    """
    # Step 1: Create vespa_account (staff takes precedence)
    account = supabase.rpc('get_or_create_account', {
        'email_param': staff['email'],
        'account_type_param': 'staff',
        'knack_attributes': knack_staff_data
    }).execute()
    
    account_id = account.data
    
    # Step 2: Update vespa_account
    supabase.table('vespa_accounts').update({
        'first_name': staff['first_name'],
        'last_name': staff['last_name'],
        'full_name': staff['full_name'],
        'school_id': establishment_uuid,
        'school_name': establishment_name
    }).eq('id', account_id).execute()
    
    # Step 3: Create vespa_staff entry
    supabase.table('vespa_staff').upsert({
        'email': staff['email'],
        'account_id': account_id,
        'school_id': establishment_uuid,
        'school_name': establishment_name,
        'department': staff.get('subject'),
        'position_title': staff.get('title'),
        'active_academic_year': '2025/2026'
    }, on_conflict='email').execute()
    
    # Step 4: Assign roles
    for role in staff['roles']:  # ['Staff Admin', 'Tutor']
        role_type = map_role_to_type(role)  # 'staff_admin', 'tutor'
        role_data = build_role_data(role, staff)
        
        supabase.rpc('assign_staff_role', {
            'email_param': staff['email'],
            'role_type_param': role_type,
            'role_data_param': role_data,
            'is_primary_param': len(staff['roles']) == 1
        }).execute()
    
    # Step 5: If staff also has Student role (emulation)
    if 'Student' in staff['roles']:
        # Create vespa_students entry too
        supabase.table('vespa_students').upsert({
            'email': staff['email'],
            'account_id': account_id,
            'school_id': establishment_uuid,
            'school_name': establishment_name,
            'current_knack_id': knack_record_id,
            'first_name': staff['first_name'],
            'last_name': staff['last_name'],
            'full_name': staff['full_name'],
            'student_group': 'EMULATED',  # Mark as emulated
            'current_academic_year': '2025/2026'
        }, on_conflict='email').execute()
```

---

## 📋 **Upload Flow: Update Account**

```python
def update_account_in_supabase(email, changes):
    """
    After updating in Knack, also update in Supabase
    """
    # Update vespa_accounts
    supabase.table('vespa_accounts').update({
        'first_name': changes.get('first_name'),
        'last_name': changes.get('last_name'),
        'full_name': changes.get('full_name'),
        'school_id': changes.get('school_id'),
        'school_name': changes.get('school_name'),
        'updated_at': datetime.now()
    }).eq('email', email).execute()
    
    # If student, update vespa_students
    student = supabase.table('vespa_students').select('id').eq('email', email).execute()
    if student.data:
        supabase.table('vespa_students').update({
            'current_year_group': changes.get('year_group'),
            'student_group': changes.get('tutor_group'),
            'updated_at': datetime.now()
        }).eq('email', email).execute()
    
    # If staff, update vespa_staff
    staff = supabase.table('vespa_staff').select('id').eq('email', email).execute()
    if staff.data:
        supabase.table('vespa_staff').update({
            'department': changes.get('subject'),
            'updated_at': datetime.now()
        }).eq('email', email).execute()
```

---

## 🔗 **Upload Flow: Update Connections**

```python
def update_student_connections(student_email, connections):
    """
    Update staff-student connections when changed in Knack
    connections = {
        'tutors': ['tut1@school.com'],
        'hoys': ['hoy1@school.com'],
        'teachers': ['teacher1@school.com']
    }
    """
    # Get student account_id
    student = supabase.table('vespa_accounts')\
        .select('id').eq('email', student_email).execute()
    
    if not student.data:
        return  # Student doesn't exist yet
    
    student_account_id = student.data[0]['id']
    
    # Delete existing connections
    supabase.table('user_connections')\
        .delete().eq('student_account_id', student_account_id).execute()
    
    # Create new connections
    for tutor_email in connections.get('tutors', []):
        supabase.rpc('create_staff_student_connection', {
            'staff_email_param': tutor_email,
            'student_email_param': student_email,
            'connection_type_param': 'tutor'
        }).execute()
    
    for hoy_email in connections.get('hoys', []):
        supabase.rpc('create_staff_student_connection', {
            'staff_email_param': hoy_email,
            'student_email_param': student_email,
            'connection_type_param': 'head_of_year'
        }).execute()
    
    for teacher_email in connections.get('teachers', []):
        supabase.rpc('create_staff_student_connection', {
            'staff_email_param': teacher_email,
            'student_email_param': student_email,
            'connection_type_param': 'subject_teacher'
        }).execute()
```

---

## 🔧 **Helper Functions Available**

### **get_or_create_account()**
```sql
SELECT get_or_create_account(
  'email@example.com',
  'student',  -- or 'staff'
  '{"id": "knack_id", "name": "John"}'::jsonb
);
-- Returns: account UUID
```

### **get_or_create_staff()**
```sql
SELECT get_or_create_staff(
  'staff@example.com',
  '{"id": "knack_id", "name": "Jane"}'::jsonb
);
-- Returns: staff UUID (creates account + staff entry)
```

### **assign_staff_role()**
```sql
SELECT assign_staff_role(
  'staff@example.com',
  'tutor',
  '{"tutor_group": "10A"}'::jsonb,
  true  -- is_primary
);
-- Returns: role UUID
```

### **create_staff_student_connection()**
```sql
SELECT create_staff_student_connection(
  'tutor@example.com',
  'student@example.com',
  'tutor',
  '{}'::jsonb
);
-- Returns: connection UUID
```

---

## 🎯 **Knack → Supabase Field Mappings**

### **Object_3 (Accounts) → vespa_accounts:**

| Knack Field | Field ID | Extract | Supabase Column |
|-------------|----------|---------|-----------------|
| Email | field_70 | `field_70_raw['email']` | email |
| Name | field_69 | `field_69_raw['first/last/title/full']` | first_name, last_name, full_name |
| User Roles | field_73 | `field_73_raw[]` → map profile_X | Determines account_type + user_roles |
| VESPA Customer | field_122 | `field_122_raw[0]['id']` | school_id |
| Account Type | field_441 | Normalize | preferences |
| Language | field_2251 | Direct | preferences.language |

### **Object_6 (Students) → vespa_students:**

| Knack Field | Field ID | Supabase Column |
|-------------|----------|-----------------|
| Student Email | field_91 | email |
| Year Group | field_548/550 | current_year_group |
| Group | field_708/565 | student_group |
| Faculty | field_1363 | (future) |
| ULN | field_3129 | sis_student_id |
| Staff Admin | field_190 | → user_connections |
| Tutor | field_1682 | → user_connections |
| Head of Year | field_547 | → user_connections |
| Subject Teachers | field_2177 | → user_connections |

---

## ⚠️ **Important Notes**

### **1. Name Cleaning:**
Some Knack records have school name prepended to full_name:
```python
if school_name in full_name:
    full_name = full_name.replace(school_name, '').strip()
```

### **2. Account Type Priority:**
```python
if has_any_staff_role:
    account_type = 'staff'  # Even if also has Student role
elif has_student_role:
    account_type = 'student'
```

### **3. Multi-Role Users:**
Staff with Student role (emulation mode):
- Create vespa_accounts with account_type='staff'
- Create BOTH vespa_staff AND vespa_students entries
- Mark student_group as 'EMULATED'

### **4. Staff Admin Connections:**
**Don't need explicit connections!** RLS handles establishment-wide access.
Only create tutor/HOY/teacher connections.

---

## 📊 **Verification Queries**

### **Check Account Exists:**
```sql
SELECT * FROM vespa_accounts WHERE email = 'user@example.com';
```

### **Check Student Profile:**
```sql
SELECT * FROM vespa_students WHERE email = 'student@example.com';
```

### **Check Staff Profile:**
```sql
SELECT * FROM vespa_staff WHERE email = 'staff@example.com';
```

### **Check Roles:**
```sql
SELECT ur.role_type, ur.role_data
FROM user_roles ur
JOIN vespa_accounts va ON ur.account_id = va.id
WHERE va.email = 'staff@example.com';
```

### **Check Connections:**
```sql
SELECT 
  staff.email as staff_email,
  student.email as student_email,
  uc.connection_type
FROM user_connections uc
JOIN vespa_accounts staff ON uc.staff_account_id = staff.id
JOIN vespa_accounts student ON uc.student_account_id = student.id
WHERE student.email = 'student@example.com';
```

---

**This is your complete schema reference for upload system integration!** 📘

