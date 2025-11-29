# Complete Knack Field Mappings - All Objects

**Date**: November 2025  
**Status**: FINAL - Ready for Migration  
**Reviewed**: Tony ✅

---

## 📚 **Object_6 - Students (23,717 active)**

### **Core Identity:**
| Knack Field | Field ID | Extract As | Supabase Target | Priority |
|-------------|----------|------------|-----------------|----------|
| Student Email | field_91 | `student['field_91']` | email | ✅ CRITICAL |
| Student Name | field_90 | `student['field_90']['first']` | first_name | ✅ CRITICAL |
| Student Name | field_90 | `student['field_90']['last']` | last_name | ✅ CRITICAL |
| Student Name | field_90 | `student['field_90_raw']` | full_name | ✅ CRITICAL |

### **School/Organization:**
| Knack Field | Field ID | Extract As | Supabase Target | Priority |
|-------------|----------|------------|-----------------|----------|
| Connected Establishment | field_179 | `student['field_179'][0]['id']` | school_id (UUID) | ✅ CRITICAL |
| Connected Establishment | field_179 | `student['field_179_raw'][0]` | school_name | ✅ CRITICAL |
| Year Group | field_548 | `student['field_548']` | current_year_group | ✅ CRITICAL |
| Faculty | field_1363 | `student['field_1363']` | faculty | ✅ IMPORTANT |
| Group (Tutor Group) | field_565 | `student['field_565']` | student_group | ✅ IMPORTANT |

### **Student ID:**
| Knack Field | Field ID | Extract As | Supabase Target | Priority |
|-------------|----------|------------|-----------------|----------|
| Student ULN | field_3129 | `student['field_3129']` | sis_student_id | ⚠️ USEFUL |

### **Staff Connection Fields (Arrays):**
| Knack Field | Field ID | Extract As | Purpose | Priority |
|-------------|----------|------------|---------|----------|
| Staff Admin(s) | field_190 | `student['field_190']` (array of emails) | Create user_connections | ✅ CRITICAL |
| Tutor(s) | field_1682 | `student['field_1682']` (array of emails) | Create user_connections | ✅ CRITICAL |
| Head(s) of Year | field_547 | `student['field_547']` (array of emails) | Create user_connections | ✅ CRITICAL |
| Subject Teacher(s) | field_2177 | `student['field_2177']` (array of emails) | Create user_connections | ✅ CRITICAL |

### **VESPA Scores Connection:**
| Knack Field | Field ID | Extract As | Supabase Target | Priority |
|-------------|----------|------------|-----------------|----------|
| Connected VESPA Result | field_182 | `student['field_182'][0]['id']` | ⚠️ NOT NEEDED | ❌ SKIP |

**Note**: VESPA scores already in Supabase `vespa_scores` table. Query by `student_email` to get scores!

---

## 👨‍💼 **Object_5 - Staff Admin (~50-100 accounts)**

### **Core Identity:**
| Knack Field | Field ID | Extract As | Supabase Target | Priority |
|-------------|----------|------------|-----------------|----------|
| Email | field_86 | `staff['field_86']` | email | ✅ CRITICAL |
| Name | field_85 | `staff['field_85']['title']` | title | ✅ IMPORTANT |
| Name | field_85 | `staff['field_85']['first']` | first_name | ✅ CRITICAL |
| Name | field_85 | `staff['field_85']['last']` | last_name | ✅ CRITICAL |
| Name | field_85 | `staff['field_85_raw']` | full_name | ✅ CRITICAL |

### **School/Organization:**
| Knack Field | Field ID | Extract As | Supabase Target | Priority |
|-------------|----------|------------|-----------------|----------|
| Connected Establishment | field_110 | `staff['field_110'][0]['id']` | school_id (UUID) | ✅ CRITICAL |
| Connected Establishment | field_110 | `staff['field_110_raw'][0]` | school_name | ✅ CRITICAL |

### **Role Information:**
- **Role Type**: `'staff_admin'`
- **Role Data**: `{"admin_level": "full", "can_manage_all": true}`
- **Is Primary**: `true` (if only role)

### **Connected Students:**
**Important**: Staff Admins don't have a "connected students" field!  
**To get their students**: Query Object_6 WHERE `field_190` contains staff admin email  
**Scope**: ALL students in their establishment

---

## 👨‍🏫 **Object_7 - Tutor (~100-200 accounts)**

### **Core Identity:**
| Knack Field | Field ID | Extract As | Supabase Target | Priority |
|-------------|----------|------------|-----------------|----------|
| Email | field_96 | `tutor['field_96']` | email | ✅ CRITICAL |
| Name | field_95 | `tutor['field_95']['title']` | title | ✅ IMPORTANT |
| Name | field_95 | `tutor['field_95']['first']` | first_name | ✅ CRITICAL |
| Name | field_95 | `tutor['field_95']['last']` | last_name | ✅ CRITICAL |
| Name | field_95 | `tutor['field_95_raw']` | full_name | ✅ CRITICAL |

### **School/Organization:**
| Knack Field | Field ID | Extract As | Supabase Target | Priority |
|-------------|----------|------------|-----------------|----------|
| Connected Establishment | field_220 | `tutor['field_220'][0]['id']` | school_id (UUID) | ✅ CRITICAL |
| Connected Establishment | field_220 | `tutor['field_220_raw'][0]` | school_name | ✅ CRITICAL |

### **Role Information:**
| Knack Field | Field ID | Extract As | Supabase Target | Priority |
|-------------|----------|------------|-----------------|----------|
| Tutor Group Name | field_562 | `tutor['field_562']` | role_data.tutor_group | ✅ CRITICAL |
| Year Group | field_562 | `tutor['field_562']` | role_data.year_group | ✅ CRITICAL |

**Note**: field_562 contains BOTH tutor group name AND year group (e.g., "10A" or "Year 10")

- **Role Type**: `'tutor'`
- **Role Data**: 
```json
{
  "tutor_group": "10A",
  "year_group": "Year 10",
  "establishment_id": "uuid"
}
```

### **Connected Students:**
**To get their students**: Query Object_6 WHERE `field_1682` contains tutor email

### **Staff Connections:**
| Knack Field | Field ID | Purpose |
|-------------|----------|---------|
| Connected Staff Admin(s) | field_225 | Tutors report to Staff Admins |

---

## 👔 **Object_18 - Head of Year (~20-50 accounts)**

### **Core Identity:**
| Knack Field | Field ID | Extract As | Supabase Target | Priority |
|-------------|----------|------------|-----------------|----------|
| Email | field_417 | `hoy['field_417']` | email | ✅ CRITICAL |
| Name | field_416 | `hoy['field_416']['title']` | title | ✅ IMPORTANT |
| Name | field_416 | `hoy['field_416']['first']` | first_name | ✅ CRITICAL |
| Name | field_416 | `hoy['field_416']['last']` | last_name | ✅ CRITICAL |
| Name | field_416 | `hoy['field_416_raw']` | full_name | ✅ CRITICAL |

### **School/Organization:**
| Knack Field | Field ID | Extract As | Supabase Target | Priority |
|-------------|----------|------------|-----------------|----------|
| Connected Establishment | field_431 | `hoy['field_431'][0]['id']` | school_id (UUID) | ✅ CRITICAL |
| Connected Establishment | field_431 | `hoy['field_431_raw'][0]` | school_name | ✅ CRITICAL |

### **Role Information:**
| Knack Field | Field ID | Extract As | Supabase Target | Priority |
|-------------|----------|------------|-----------------|----------|
| Year Group Responsible | field_433 | `hoy['field_433']` | role_data.year_group | ✅ CRITICAL |

- **Role Type**: `'head_of_year'`
- **Role Data**:
```json
{
  "year_group": "Year 10",
  "establishment_id": "uuid"
}
```

### **Connected Students:**
**To get their students**: Query Object_6 WHERE `field_547` contains HOY email

### **Staff Connections:**
| Knack Field | Field ID | Purpose |
|-------------|----------|---------|
| Connected Staff Admin(s) | field_432 | HOY reports to Staff Admins |

---

## 👨‍🔬 **Object_78 - Subject Teacher (~100-200 accounts)**

### **Core Identity:**
| Knack Field | Field ID | Extract As | Supabase Target | Priority |
|-------------|----------|------------|-----------------|----------|
| Email | field_1879 | `teacher['field_1879']` | email | ✅ CRITICAL |
| Name | field_1878 | `teacher['field_1878']['title']` | title | ✅ IMPORTANT |
| Name | field_1878 | `teacher['field_1878']['first']` | first_name | ✅ CRITICAL |
| Name | field_1878 | `teacher['field_1878']['last']` | last_name | ✅ CRITICAL |
| Name | field_1878 | `teacher['field_1878_raw']` | full_name | ✅ CRITICAL |

### **School/Organization:**
| Knack Field | Field ID | Extract As | Supabase Target | Priority |
|-------------|----------|------------|-----------------|----------|
| Connected Establishment | field_1883 | `teacher['field_1883'][0]['id']` | school_id (UUID) | ✅ CRITICAL |
| Connected Establishment | field_1883 | `teacher['field_1883_raw'][0]` | school_name | ✅ CRITICAL |

### **Role Information:**
| Knack Field | Field ID | Extract As | Supabase Target | Priority |
|-------------|----------|------------|-----------------|----------|
| Subject | field_1885 | `teacher['field_1885']` | role_data.subject | ✅ CRITICAL |
| Classes | ❌ NOT YET IN KNACK | N/A | role_data.classes | ⚠️ TO ADD |

- **Role Type**: `'subject_teacher'`
- **Role Data**:
```json
{
  "subject": "Mathematics",
  "classes": [],  // Empty for now until field created in Knack
  "establishment_id": "uuid"
}
```

### **Connected Students:**
**To get their students**: Query Object_6 WHERE `field_2177` contains teacher email

---

## 🔑 **Key Architectural Insights:**

### **1. Reverse Relationships (Critical Understanding!)**

```
Knack:
Student Record (Object_6)
├── field_190: [staffadmin1@, staffadmin2@]
├── field_1682: [tutor1@]
├── field_547: [hoy1@]
└── field_2177: [teacher1@, teacher2@]

To get Tutor's students:
→ Query Object_6 WHERE field_1682 contains tutor@email.com
```

**Migration Strategy:**
```python
# For each student
for student in students:
    # Extract staff connections from student record
    staff_admins = student['field_190']  # Array of emails
    tutors = student['field_1682']       # Array of emails
    hoys = student['field_547']          # Array of emails
    teachers = student['field_2177']     # Array of emails
    
    # Create connections (reverse the relationship)
    for staff_email in staff_admins:
        create_connection(staff_email, student_email, 'staff_admin')
    
    for tutor_email in tutors:
        create_connection(tutor_email, student_email, 'tutor')
    
    # etc...
```

### **2. Staff Admins Have Full School Access**

```sql
-- Staff Admins see ALL students in their establishment
-- Don't need explicit connections (RLS handles this)

CREATE POLICY "staff_admins_see_all_establishment_students"
ON vespa_students FOR SELECT
USING (
  school_id IN (
    SELECT school_id FROM vespa_staff
    WHERE email = current_user_email()
    AND account_id IN (
      SELECT account_id FROM user_roles 
      WHERE role_type = 'staff_admin'
    )
  )
);
```

### **3. VESPA Scores Query Pattern:**

```python
# Get student's current VESPA scores
def get_student_vespa_scores(student_email, cycle=None):
    query = supabase.table('vespa_scores')\
        .select('vision, effort, systems, practice, attitude, cycle, academic_year, level')\
        .eq('student_email', student_email)
    
    if cycle:
        query = query.eq('cycle', cycle)
    else:
        # Get latest
        query = query.order('created_at', desc=True).limit(1)
    
    return query.execute()

# Already working! No import needed! ✅
```

---

## 📊 **Migration Data Summary:**

### **What Gets Imported:**

| Object | Count | Email Field | Establishment Field | Connection Method |
|--------|-------|-------------|---------------------|-------------------|
| Object_6 (Students) | 23,717 | field_91 | field_179 | Direct |
| Object_5 (Staff Admin) | ~50-100 | field_86 | field_110 | Via student connections |
| Object_7 (Tutor) | ~100-200 | field_96 | field_220 | Via student connections |
| Object_18 (HOY) | ~20-50 | field_417 | field_431 | Via student connections |
| Object_78 (Subject Teacher) | ~100-200 | field_1879 | field_1883 | Via student connections |

**Total**: ~24,000 accounts (students + staff)

---

## 🔧 **Migration Script Structure:**

### **Phase 1: Import Students**

```python
for student in get_knack_students():
    # Extract data
    data = {
        'email': student['field_91'],
        'first_name': student['field_90']['first'],
        'last_name': student['field_90']['last'],
        'full_name': student['field_90_raw'],
        'school_id': student['field_179'][0]['id'],  # UUID from establishments
        'school_name': student['field_179_raw'][0],
        'year_group': student['field_548'],
        'faculty': student.get('field_1363'),
        'student_group': student.get('field_565'),
        'sis_student_id': student.get('field_3129')
    }
    
    # Store staff connections for later
    staff_connections = {
        'staff_admins': student.get('field_190', []),   # Array of emails
        'tutors': student.get('field_1682', []),        # Array of emails
        'hoys': student.get('field_547', []),           # Array of emails
        'teachers': student.get('field_2177', [])       # Array of emails
    }
    
    # Create account + student record
    create_student(data, staff_connections)
```

### **Phase 2: Import Staff (All Types)**

```python
# For each staff type
for staff_type, object_key in [
    ('staff_admin', 'object_5'),
    ('tutor', 'object_7'),
    ('head_of_year', 'object_18'),
    ('subject_teacher', 'object_78')
]:
    staff_records = get_knack_records(object_key)
    
    for staff in staff_records:
        # Extract based on staff type...
        create_staff(staff, staff_type)
```

### **Phase 3: Create Connections**

```python
# Process stored connections from Phase 1
for student_email, connections in student_connections.items():
    for staff_admin in connections['staff_admins']:
        create_connection(staff_admin, student_email, 'staff_admin')
    
    for tutor in connections['tutors']:
        create_connection(tutor, student_email, 'tutor')
    
    # etc...
```

---

## ✅ **Confirmed Understanding:**

1. ✅ Students connect TO staff (not vice versa)
2. ✅ Staff connections stored in Object_6 (student records)
3. ✅ Name fields have title for staff, not for students
4. ✅ Year Group is field_548 (not field_112)
5. ✅ VESPA scores already in Supabase (don't re-import)
6. ✅ Establishments table already exists
7. ✅ Faculty and Group fields important for filtering
8. ✅ Staff Admins have establishment-wide access

---

## 🎯 **Ready to Code?**

With these field mappings, I can now create:
1. Complete student migration script
2. Complete staff migration script
3. Connection builder script

All with correct field IDs and proper data extraction!

**Any questions before I update the migration scripts?**

