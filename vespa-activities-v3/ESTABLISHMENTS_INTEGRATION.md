# Establishments Integration for Activities V3

**Date**: November 2025  
**Status**: Ready for Implementation

---

## 🏫 **Establishments Table (Existing)**

### **Structure:**

```sql
establishments (Knack Object_2):
├── id (UUID) - Primary key
├── knack_id (VARCHAR) - Links to Knack
├── name (VARCHAR) - School name
├── trust_id (UUID) - Multi-academy trust
├── is_australian (BOOLEAN) - For Australian schools
├── status (VARCHAR) - Default: 'Active'
├── use_standard_year (BOOLEAN) - Year group settings
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)
```

### **Current State:**
- **Total establishments**: (to be confirmed)
- **Linked students in legacy table**: 32,595 students
- **VESPA ACADEMY test school**: (to be confirmed)

---

## 🔗 **Integration with Hybrid Architecture**

### **Foreign Key Relationships:**

```sql
vespa_accounts
├── school_id UUID REFERENCES establishments(id)
└── school_name VARCHAR (denormalized)

vespa_students  
├── school_id UUID REFERENCES establishments(id)
└── school_name VARCHAR (denormalized)

vespa_staff
├── school_id UUID REFERENCES establishments(id)
└── school_name VARCHAR (denormalized)
```

**Why denormalize school_name?**
- Performance: Avoid JOIN on every query
- Common query pattern: Filter by school name
- Small data redundancy cost vs big performance gain

---

## 🔐 **Row Level Security by Establishment**

### **Critical Security Policies:**

```sql
-- Staff can only see students from their establishment(s)
CREATE POLICY "staff_see_own_establishment_students" 
ON vespa_students FOR SELECT 
USING (
  school_id IN (
    SELECT school_id 
    FROM vespa_staff 
    WHERE email = current_setting('request.jwt.claims', true)::json->>'email'
  )
);

-- Students can only see their own data
CREATE POLICY "students_see_own_data" 
ON vespa_students FOR SELECT 
USING (
  email = current_setting('request.jwt.claims', true)::json->>'email'
);

-- Activities visible to students from active establishments only
CREATE POLICY "activities_for_active_establishments"
ON activity_responses FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM vespa_students vs
    JOIN establishments e ON vs.school_id = e.id
    WHERE vs.email = activity_responses.student_email
    AND e.status = 'Active'
  )
);

-- Staff can only see connections to their establishment students
CREATE POLICY "staff_connections_own_establishment"
ON user_connections FOR SELECT
USING (
  staff_account_id IN (
    SELECT account_id FROM vespa_staff
    WHERE email = current_setting('request.jwt.claims', true)::json->>'email'
  )
  AND student_account_id IN (
    SELECT account_id FROM vespa_students
    WHERE school_id IN (
      SELECT school_id FROM vespa_staff 
      WHERE email = current_setting('request.jwt.claims', true)::json->>'email'
    )
  )
);
```

---

## 🧪 **Testing Strategy with VESPA ACADEMY**

### **Phase 1: Test Migration (VESPA ACADEMY Only)**

```python
# 06_TEST_migrate_vespa_academy.py

import os
from supabase import create_client
from knack_api import KnackAPI

# Get VESPA ACADEMY establishment
vespa_academy = supabase.table('establishments')\
    .select('id, name, knack_id')\
    .ilike('name', '%VESPA%ACADEMY%')\
    .single()\
    .execute()

print(f"🏫 Test School: {vespa_academy.data['name']}")
print(f"📍 Establishment ID: {vespa_academy.data['id']}")

# Get VESPA ACADEMY students from Knack
knack = KnackAPI(app_id, api_key)
knack_students = knack.get_records('object_6', filters={
    'field_82': vespa_academy.data['knack_id']  # Establishment connection field
})

print(f"👥 Found {len(knack_students)} VESPA ACADEMY students in Knack")

# Migrate each student
for student in knack_students:
    # Check if already in vespa_students
    existing = supabase.table('vespa_students')\
        .select('id')\
        .eq('email', student['email'])\
        .execute()
    
    if existing.data:
        print(f"⏭️  Skip: {student['email']} (already exists)")
        continue
    
    # Create in vespa_accounts
    account = supabase.rpc('get_or_create_account', {
        'email_param': student['email'],
        'account_type_param': 'student',
        'knack_attributes': student
    }).execute()
    
    # Update vespa_accounts with establishment
    supabase.table('vespa_accounts')\
        .update({
            'school_id': vespa_academy.data['id'],
            'school_name': vespa_academy.data['name']
        })\
        .eq('id', account.data)\
        .execute()
    
    # Create in vespa_students
    supabase.table('vespa_students').insert({
        'email': student['email'],
        'account_id': account.data,
        'school_id': vespa_academy.data['id'],
        'school_name': vespa_academy.data['name'],
        'current_knack_id': student['knack_id'],
        'first_name': student['first_name'],
        'last_name': student['last_name'],
        'full_name': student['name'],
        'current_year_group': student['year_group'],
        'current_academic_year': student['academic_year'],
        # ... other fields
    }).execute()
    
    print(f"✅ Migrated: {student['email']}")

print("\n✅ VESPA ACADEMY migration complete!")
```

### **Phase 2: Test Staff Migration (VESPA ACADEMY Staff)**

```python
# 07_TEST_migrate_vespa_academy_staff.py

# Get VESPA ACADEMY staff from Knack
vespa_academy_staff = []

# Query each staff object
for obj in ['object_5', 'object_7', 'object_18', 'object_78']:
    staff = knack.get_records(obj, filters={
        # Filter by establishment connection
        'establishment_field': vespa_academy.data['knack_id']
    })
    vespa_academy_staff.extend(staff)

print(f"👨‍🏫 Found {len(vespa_academy_staff)} VESPA ACADEMY staff")

for staff in vespa_academy_staff:
    # Create staff account
    staff_id = supabase.rpc('get_or_create_staff', {
        'email_param': staff['email'],
        'knack_attributes': staff
    }).execute()
    
    # Update with establishment
    supabase.table('vespa_staff')\
        .update({
            'school_id': vespa_academy.data['id'],
            'school_name': vespa_academy.data['name'],
            'department': staff.get('department'),
            'position_title': staff.get('position')
        })\
        .eq('email', staff['email'])\
        .execute()
    
    # Assign roles
    for role in staff['roles']:
        supabase.rpc('assign_staff_role', {
            'email_param': staff['email'],
            'role_type_param': role,
            'role_data_param': {
                'establishment_id': vespa_academy.data['id'],
                'establishment_name': vespa_academy.data['name']
            }
        }).execute()
    
    # Create student connections (only to VESPA ACADEMY students)
    for student_email in staff['connected_students']:
        # Verify student is from VESPA ACADEMY
        student = supabase.table('vespa_students')\
            .select('email')\
            .eq('email', student_email)\
            .eq('school_id', vespa_academy.data['id'])\
            .execute()
        
        if not student.data:
            print(f"⚠️  Skip connection: {student_email} not in VESPA ACADEMY")
            continue
        
        supabase.rpc('create_staff_student_connection', {
            'staff_email_param': staff['email'],
            'student_email_param': student_email,
            'connection_type_param': role
        }).execute()
    
    print(f"✅ Migrated staff: {staff['email']}")
```

### **Phase 3: Verify Establishment Isolation**

```sql
-- Check VESPA ACADEMY data isolation
SELECT 
  'vespa_accounts' as table_name,
  COUNT(*) as vespa_academy_records
FROM vespa_accounts
WHERE school_id = '<vespa_academy_id>';

SELECT 
  'vespa_students' as table_name,
  COUNT(*) as vespa_academy_records
FROM vespa_students
WHERE school_id = '<vespa_academy_id>';

SELECT 
  'vespa_staff' as table_name,
  COUNT(*) as vespa_academy_records
FROM vespa_staff
WHERE school_id = '<vespa_academy_id>';

SELECT 
  'user_connections' as table_name,
  COUNT(*) as vespa_academy_connections
FROM user_connections uc
JOIN vespa_students vs ON uc.student_account_id = vs.account_id
WHERE vs.school_id = '<vespa_academy_id>';

-- Verify no cross-establishment leakage
SELECT 
  staff.email as staff_email,
  staff.school_name as staff_school,
  student.school_name as student_school,
  CASE 
    WHEN staff.school_id != student.school_id THEN '❌ LEAK!'
    ELSE '✅ OK'
  END as check
FROM user_connections uc
JOIN vespa_staff staff ON uc.staff_account_id = staff.account_id
JOIN vespa_students student ON uc.student_account_id = student.account_id
WHERE staff.school_id != student.school_id;

-- Should return 0 rows
```

---

## 🚀 **Full Migration Strategy (After Testing)**

### **Step 1: Run ADDITIVE_HYBRID_MIGRATION.sql**
- Creates vespa_accounts with establishment FK
- Migrates existing 4,834 vespa_students
- Links to establishments from legacy students table

### **Step 2: Test with VESPA ACADEMY**
- Run 06_TEST_migrate_vespa_academy.py
- Run 07_TEST_migrate_vespa_academy_staff.py
- Verify isolation with SQL queries above
- Test activities assignment and completion

### **Step 3: Full Migration (All Establishments)**
- Run 06_migrate_all_active_students.py
- Run 07_migrate_all_staff_and_connections.py
- Verify each establishment independently

---

## 📊 **Benefits of Establishment Integration**

| Benefit | Impact |
|---------|--------|
| **Data Isolation** | Schools can only see their own data |
| **Security** | RLS enforces at database level |
| **Multi-Tenancy** | One database, multiple schools |
| **Performance** | Index on school_id for fast queries |
| **Scalability** | Add new schools without schema changes |
| **Testing** | VESPA ACADEMY as isolated test environment |

---

## ⚠️ **Critical Considerations**

### **Multi-Academy Trusts (MATs)**
Some staff may work across multiple schools in a trust:
```sql
-- Staff with multiple establishments via trust
SELECT 
  vs.email,
  array_agg(DISTINCT e.name) as schools
FROM vespa_staff vs
JOIN establishments e1 ON vs.school_id = e1.id
JOIN establishments e2 ON e1.trust_id = e2.trust_id
JOIN establishments e ON e.trust_id = e1.trust_id
GROUP BY vs.email
HAVING COUNT(DISTINCT e.id) > 1;
```

**Solution:** Store primary establishment in vespa_staff, allow connections across trust via user_connections.

### **Year Rollovers**
Students may change establishment (rare):
```sql
-- Track establishment changes
ALTER TABLE vespa_students 
ADD COLUMN previous_establishments JSONB DEFAULT '[]'::jsonb;

-- When establishment changes
UPDATE vespa_students
SET 
  previous_establishments = previous_establishments || 
    jsonb_build_object(
      'establishment_id', school_id,
      'establishment_name', school_name,
      'from_date', enrollment_date,
      'to_date', NOW()
    ),
  school_id = new_establishment_id,
  school_name = new_establishment_name
WHERE email = student_email;
```

---

## ✅ **Next Steps**

1. ✅ Confirm VESPA ACADEMY exists in establishments table
2. ✅ Run ADDITIVE_HYBRID_MIGRATION.sql
3. ✅ Test migration with VESPA ACADEMY only
4. ✅ Verify establishment isolation and RLS
5. ✅ If successful, migrate all establishments
6. ✅ Update onboarding to include establishment

---

**Establishments are the foundation of data isolation and security!** 🏫🔐

