# Final Field Reference - Complete & Verified

**Date**: November 2025  
**Status**: ✅ VERIFIED BY TONY - Ready for Production  
**Source**: Object_3 (Accounts) as primary, Object_6 (Students) for connections

---

## 🔑 **Object_3 - Accounts (Master Registry)**

### **Primary Source for ALL Users**

| Field Name | Field ID | Type | Extract Pattern | Supabase Target | Priority |
|------------|----------|------|-----------------|-----------------|----------|
| **Email** | field_70 | Email | `account['field_70']` | email | ✅ CRITICAL |
| **Name** | field_69 | Person | `account['field_69']` (object) | first_name, last_name, title | ✅ CRITICAL |
| **User Roles** | field_73 | Multiple Choice | `account['field_73']` (array) | Determines account_type + user_roles | ✅ CRITICAL |
| **VESPA Customer** | field_122 | Connection | `account['field_122'][0]['id']` | school_id (UUID) | ✅ CRITICAL |
| **Account Type** | field_441 | Short Text | `account['field_441']` | account_type_raw | ✅ CRITICAL |
| **User Status** | field_72 | Multiple Choice | `account['field_72']` | status | ✅ IMPORTANT |
| **Year Group** | field_550 | Short Text | `account['field_550']` | current_year_group | ✅ IMPORTANT |
| **Group** | field_708 | Short Text | `account['field_708']` | student_group | ✅ IMPORTANT |
| **Subject** | field_551 | Short Text | `account['field_551']` | role_data.subject | ✅ IMPORTANT |
| **Subject Code** | field_2178 | Short Text | `account['field_2178']` | role_data.subject_code | ⚠️ USEFUL |
| **Teaching Group** | field_129 | Short Text | `account['field_129']` | role_data.teaching_group | ⚠️ USEFUL |
| **Language** | field_2251 | Multiple Choice | `account['field_2251']` | preferences.language | ⚠️ USEFUL |
| **Verified User** | field_189 | Yes/No | `account['field_189']` | verified | ⚠️ USEFUL |

---

## 🎭 **User Roles (field_73) - Possible Values:**

### **Active Roles:**
- `"Student"` → Creates vespa_students entry
- `"Staff Admin"` → Creates vespa_staff + user_role (establishment-wide access)
- `"Tutor"` → Creates vespa_staff + user_role
- `"Head of Year"` → Creates vespa_staff + user_role
- `"Subject Teacher"` → Creates vespa_staff + user_role

### **Legacy Roles (Keep for Future):**
- `"Head of Department"` → Import but mark as legacy
- `"Parent"` → Import but mark as legacy
- `"General Staff"` → Import (view-only access)

**Multi-Role Support**: One person can have ["Student", "Tutor"] or ["Staff Admin", "Head of Year"]

---

## 🏢 **Account Type (field_441) - Normalization Rules:**

### **Valid Values:**
- `"COACHING PORTAL"` → Keep as-is ✅
- `"RESOURCE PORTAL"` → Keep as-is ✅

### **Legacy Values (Normalize to COACHING PORTAL):**
- `"Coaching"` → "COACHING PORTAL"
- `"Gold"` → "COACHING PORTAL"
- `"Silver"` → "COACHING PORTAL"
- `"Bronze"` → "COACHING PORTAL"
- `"Resource"` → "RESOURCE PORTAL"
- `"Resources"` → "RESOURCE PORTAL"

### **NULL/Blank Values:**
```python
if not account_type or account_type.strip() == '':
    # Derive from roles
    if 'Student' in roles:
        account_type = 'COACHING PORTAL'
    else:
        account_type = 'COACHING PORTAL'  # Default for staff
    
    # Flag for review
    flag_for_manual_review(email, 'missing_account_type')
```

---

## 📚 **Object_6 - Students (Connection Source)**

### **Only Need These Fields for Connections:**

| Field Name | Field ID | Type | Purpose |
|------------|----------|------|---------|
| Student Email | field_91 | Email | Identifier |
| Staff Admin(s) | field_190 | Connection Array | Staff Admin connections |
| Tutor(s) | field_1682 | Connection Array | Tutor connections |
| Head(s) of Year | field_547 | Connection Array | HOY connections |
| Subject Teacher(s) | field_2177 | Connection Array | Teacher connections |

**Extract Pattern:**
```python
student = knack_api.get('object_6', record_id)

connections = {
    'staff_admins': [conn['email'] for conn in student.get('field_190', [])],
    'tutors': [conn['email'] for conn in student.get('field_1682', [])],
    'hoys': [conn['email'] for conn in student.get('field_547', [])],
    'teachers': [conn['email'] for conn in student.get('field_2177', [])]
}
```

---

## 🔐 **RLS Strategy by Role:**

### **Staff Admins (Establishment-Wide):**
```sql
-- No explicit connections needed
-- RLS grants access to all users in their establishment
WHERE school_id IN (
  SELECT school_id FROM vespa_staff 
  WHERE email = current_user() 
  AND has_role('staff_admin')
)
```

### **Tutors/HOY/Teachers (Specific Students):**
```sql
-- Requires explicit user_connections
WHERE account_id IN (
  SELECT student_account_id FROM user_connections
  WHERE staff_account_id = current_account_id()
  AND connection_type = 'tutor'  -- or 'head_of_year', 'subject_teacher'
)
```

---

## 📊 **Connection Matrix:**

| Staff Role | Access Scope | Connection Type | Source |
|------------|--------------|-----------------|--------|
| **Staff Admin** | All students + staff in establishment | ❌ No explicit connections | RLS policy |
| **Tutor** | Assigned tutees only | ✅ Explicit connections | Object_6 field_1682 |
| **Head of Year** | Assigned year group students | ✅ Explicit connections | Object_6 field_547 |
| **Subject Teacher** | Assigned class students | ✅ Explicit connections | Object_6 field_2177 |
| **General Staff** | View-only all students | ❌ No connections | RLS policy |

---

## 🎯 **Migration Sequence:**

### **Phase 1: Accounts (Object_3)**
1. Query Object_3 (all active, non-dummy accounts)
2. Normalize account_type (field_441)
3. Create vespa_accounts for all
4. Create vespa_students (if "Student" in roles)
5. Create vespa_staff (if ANY staff role in roles)
6. Create user_roles (for each staff role)

**Result**: ~24,000 accounts created, all with proper roles

### **Phase 2: Connections (Object_6)**
1. Query Object_6 (just connection fields)
2. Build user_connections for:
   - Tutors (field_1682)
   - HOYs (field_547)
   - Subject Teachers (field_2177)
3. Skip Staff Admins (RLS handles them)

**Result**: ~50,000-100,000 connections created

---

## 🧪 **Test Data (VESPA ACADEMY):**

| Metric | Expected |
|--------|----------|
| Object_3 accounts | ~ accounts with VESPA ACADEMY in field_122 |
| Students | Subset with "Student" role |
| Staff | Subset with staff roles |
| Multi-role users | Some accounts with both student + staff roles |

---

## ⚠️ **Edge Cases to Handle:**

1. **Multi-Role Users**: Sarah is ["Student", "Tutor"]
   - Create vespa_students entry ✅
   - Create vespa_staff entry ✅
   - Create user_role for "tutor" ✅
   - She can switch between student view and tutor view

2. **Account Type Mismatch**: Student with account_type = "RESOURCE PORTAL"
   - Import anyway ✅
   - Flag for review ✅
   - Might be data error or special case

3. **Missing Establishment**: Account with no field_122
   - Skip import ❌
   - Log error ✅
   - Can't function without establishment

4. **Duplicate Emails**: Same email in multiple roles
   - Knack prevents this (unique email) ✅
   - Our constraints prevent it ✅

---

## ✅ **Ready for Implementation**

All field IDs confirmed. All business rules documented. Ready to code!

**Next**: Create complete migration scripts with proper field extraction, normalization, and connection building.

