# Handling Knack Connection Fields - Complete Guide

**Date**: November 2025  
**Status**: ✅ VERIFIED via API Testing  
**Source**: Live Knack API Response Analysis

---

## 🔑 **Critical Discovery: Always Use `_raw` Fields!**

### **Knack Returns TWO Versions of Each Field:**

| Field Type | Formatted Version | Raw Version | Use Which? |
|------------|-------------------|-------------|------------|
| **Email** | `<a href="mailto:...">email</a>` (HTML) | `{"email": "...", "label": "..."}` | ✅ `_raw` |
| **Name** | `"John Smith"` (string) | `{"first": "John", "last": "Smith", "title": "Mr"}` | ✅ `_raw` |
| **Roles** | `<span>Student</span>` (HTML) | `["profile_6"]` (array of IDs) | ✅ `_raw` |
| **Connection** | `<span>School Name</span>` (HTML) | `[{"id": "uuid", "identifier": "name"}]` | ✅ `_raw` |

**Rule**: **ALWAYS use `field_XXX_raw` for data extraction!**

---

## 📋 **Profile ID to Role Name Mapping**

### **User Roles (field_73_raw):**

```python
PROFILE_TO_ROLE = {
    'profile_6': 'Student',
    'profile_5': 'Staff Admin',
    'profile_7': 'Tutor',
    'profile_18': 'Head of Year',
    'profile_78': 'Subject Teacher',
    'profile_XX': 'Head of Department',  # Need to verify
    'profile_XX': 'General Staff',       # Need to verify
    'profile_XX': 'Parent'               # Need to verify
}

# Extract roles
raw_roles = account.get('field_73_raw', [])  # ["profile_6", "profile_7"]
roles = [PROFILE_TO_ROLE.get(profile_id, profile_id) for profile_id in raw_roles]
# Result: ["Student", "Tutor"]
```

---

## 📊 **Field Extraction Patterns**

### **Email (field_70):**

```python
# ❌ WRONG:
email = account.get('field_70')
# Returns: "<a href=\"mailto:user@email.com\">user@email.com</a>"

# ✅ CORRECT:
email_data = account.get('field_70_raw', {})
email = email_data.get('email')
# Returns: "user@email.com"
```

### **Name (field_69):**

```python
# ❌ WRONG:
name = account.get('field_69')
# Returns: "Mr John Smith" (string - hard to parse)

# ✅ CORRECT:
name_data = account.get('field_69_raw', {})
first = name_data.get('first')
last = name_data.get('last')
title = name_data.get('title')
full = name_data.get('full')
# Returns: Clean separated components
```

### **Establishment (field_122):**

```python
# ❌ WRONG:
establishment = account.get('field_122')
# Returns: "<span class=\"uuid\">School Name</span>"

# ✅ CORRECT:
establishment_data = account.get('field_122_raw', [])
if establishment_data:
    establishment_id = establishment_data[0]['id']
    establishment_name = establishment_data[0]['identifier']
# Returns: Clean UUID and name
```

### **User Roles (field_73):**

```python
# ❌ WRONG:
roles = account.get('field_73')
# Returns: "<span class=\"profile_6\">Student</span>"

# ✅ CORRECT:
profile_ids = account.get('field_73_raw', [])
# Returns: ["profile_6"]

# Map to role names
PROFILE_MAP = {
    'profile_6': 'Student',
    'profile_5': 'Staff Admin',
    'profile_7': 'Tutor',
    'profile_18': 'Head of Year',
    'profile_78': 'Subject Teacher'
}

roles = [PROFILE_MAP.get(pid, pid) for pid in profile_ids]
# Returns: ["Student"]
```

---

## 🔗 **Connection Fields (Object_6)**

### **Staff Connections:**

```python
# Object_6 connection fields
# field_190 - Staff Admins
# field_1682 - Tutors
# field_547 - Heads of Year
# field_2177 - Subject Teachers

# ❌ WRONG:
tutors = student.get('field_1682')
# Returns: "<span>Tutor Name</span>" or similar

# ✅ CORRECT:
tutors_raw = student.get('field_1682_raw', [])
# Returns: [
#   {"id": "record_id", "identifier": "tutor@email.com"},
#   {"id": "record_id2", "identifier": "tutor2@email.com"}
# ]

tutor_emails = [t['identifier'] for t in tutors_raw]
# Returns: ["tutor@email.com", "tutor2@email.com"]
```

**Pattern for ALL connection fields:**
```python
def extract_connection_emails(field_raw_data):
    """Extract emails from Knack connection field"""
    if not field_raw_data:
        return []
    
    if isinstance(field_raw_data, list):
        return [conn.get('identifier') for conn in field_raw_data if conn.get('identifier')]
    
    return []

# Usage:
staff_admins = extract_connection_emails(student.get('field_190_raw', []))
tutors = extract_connection_emails(student.get('field_1682_raw', []))
hoys = extract_connection_emails(student.get('field_547_raw', []))
teachers = extract_connection_emails(student.get('field_2177_raw', []))
```

---

## 📋 **Complete Extraction Template**

```python
def extract_account_data(account):
    """Extract data from Knack Object_3 account using _raw fields"""
    
    # Email
    email_raw = account.get('field_70_raw', {})
    email = email_raw.get('email') if isinstance(email_raw, dict) else account.get('field_70')
    
    # Name
    name_raw = account.get('field_69_raw', {})
    if isinstance(name_raw, dict):
        first_name = name_raw.get('first', '')
        last_name = name_raw.get('last', '')
        title = name_raw.get('title', '')
        full_name = name_raw.get('full', '')
    else:
        # Fallback to string parsing
        full_name = account.get('field_69', '')
        parts = full_name.split()
        first_name = parts[0] if parts else ''
        last_name = ' '.join(parts[1:]) if len(parts) > 1 else ''
        title = ''
    
    # Roles (profile IDs → role names)
    PROFILE_TO_ROLE = {
        'profile_6': 'Student',
        'profile_5': 'Staff Admin',
        'profile_7': 'Tutor',
        'profile_18': 'Head of Year',
        'profile_78': 'Subject Teacher'
    }
    
    profile_ids = account.get('field_73_raw', [])
    roles = [PROFILE_TO_ROLE.get(pid, pid) for pid in profile_ids]
    
    # Establishment
    establishment_raw = account.get('field_122_raw', [])
    establishment_id = establishment_raw[0]['id'] if establishment_raw else None
    establishment_name = establishment_raw[0]['identifier'] if establishment_raw else None
    
    # Other fields
    year_group = account.get('field_550_raw', '') or account.get('field_550', '')
    student_group = account.get('field_708_raw', '') or account.get('field_708', '')
    subject = account.get('field_551_raw', '') or account.get('field_551', '')
    
    return {
        'email': email,
        'first_name': first_name,
        'last_name': last_name,
        'title': title,
        'full_name': full_name,
        'roles': roles,
        'establishment_id': establishment_id,
        'establishment_name': establishment_name,
        'year_group': year_group,
        'student_group': student_group,
        'subject': subject
    }
```

---

## ✅ **Sample API Response (Verified):**

```json
{
  "field_70": "<a href=\"mailto:email\">email</a>",
  "field_70_raw": {
    "email": "antoinecottereau@student.st-annes.uk.com",
    "label": "antoinecottereau@student.st-annes.uk.com"
  },
  
  "field_69": "Antoine cottereau",
  "field_69_raw": {
    "first": "Antoine",
    "middle": "",
    "last": "cottereau",
    "title": "",
    "full": "Antoine cottereau"
  },
  
  "field_73": "<span class=\"profile_6\">Student</span>",
  "field_73_raw": ["profile_6"],
  
  "field_122": "<span>St Anne's Catholic School</span>",
  "field_122_raw": [{
    "id": "6151854531ad6a001e421979",
    "identifier": "St Anne's Catholic School & Sixth Form College "
  }]
}
```

---

## 🎯 **Migration Script Fixes Needed:**

1. **Use `field_70_raw['email']`** not `field_70`
2. **Use `field_69_raw`** not `field_69`
3. **Use `field_73_raw`** and map profile IDs to role names
4. **Use `field_122_raw[0]['id']`** for establishment UUID
5. **Use `_raw` for ALL connection fields** in Object_6

---

## 📚 **Profile ID Reference:**

| Profile ID | Object | Role Name | Object ID |
|------------|--------|-----------|-----------|
| profile_6 | Students | Student | object_6 |
| profile_5 | Staff Admins | Staff Admin | object_5 |
| profile_7 | Tutors | Tutor | object_7 |
| profile_18 | Heads of Year | Head of Year | object_18 |
| profile_78 | Subject Teachers | Subject Teacher | object_78 |

---

**This explains EVERYTHING!** The script was checking for "Student", "Tutor" in field_73, but Knack returns "profile_6", "profile_7"!

**Next**: Update the migration script to use `_raw` fields and profile ID mapping! 🎯

