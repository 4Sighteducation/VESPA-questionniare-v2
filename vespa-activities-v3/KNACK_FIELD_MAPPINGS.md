# Knack Field Mappings - Complete Reference

**Date**: November 2025  
**Purpose**: Document all Knack fields being imported to Supabase  
**Status**: For review before migration

---

## 📚 **Object_6 - Students (23,717 active accounts)**

### **Currently Being Imported (Basic Fields):**

| Knack Field | Field ID | Type | Supabase Column | Priority | Notes |
|-------------|----------|------|-----------------|----------|-------|
| Student Email | field_91 | Email | email | ✅ CRITICAL | Primary identifier |
| First Name | field_88 | Text | first_name | ✅ CRITICAL | |
| Last Name | field_89 | Text | last_name | ✅ CRITICAL | |
| Student Name | field_90 | Name | full_name | ✅ CRITICAL | Full display name |
| Phone Number | field_92 | Phone | phone_number | ⚠️ IMPORTANT | Contact info |
| Year Group | field_112 | Text | current_year_group | ✅ CRITICAL | Year 7-13 |
| Academic Year | field_204 | Text | current_academic_year | ✅ CRITICAL | e.g., "2025/2026" |

### **Connection Fields (Available but NOT Currently Imported):**

| Knack Field | Field ID | Type | Purpose | Import? |
|-------------|----------|------|---------|---------|
| Connected VESPA Customer | field_179 | Connection → Object_2 | School/Establishment | ✅ YES - Use for school_id |
| Connected VESPA Result | field_182 | Connection → Object_10 | Latest questionnaire | ⚠️ Maybe - For VESPA scores |
| Connected Staff Admin(s) | field_190 | Connection → Object_5 | Staff relationships | ✅ YES - For user_connections |
| Connected Tutor(s) | field_1682 | Connection → Object_7 | Tutor relationships | ✅ YES - For user_connections |
| Connected Heads of Year | field_547 | Connection → Object_18 | HOY relationships | ✅ YES - For user_connections |
| Connected Subject Teachers | field_2177 | Connection → Object_78 | Teacher relationships | ✅ YES - For user_connections |

### **Activity-Related Fields (Available but handled separately):**

| Knack Field | Field ID | Type | Purpose | Import? |
|-------------|----------|------|---------|---------|
| Prescribed Activities | field_1683 | Connection → Object_44 | Curriculum activities | ❌ NO - Use Supabase activities |
| Finished Activities | field_1380 | Short Text | CSV of completed IDs | ❌ NO - Use activity_responses |
| New User | field_3655 | Yes/No | First-time user flag | ⚠️ Maybe - For onboarding |
| Activity History | field_3656 | JSON | Legacy activity data | ❌ NO - Use activity_responses |

### **Additional Student Fields (Available):**

| Knack Field | Field ID | Type | Import? | Notes |
|-------------|----------|------|---------|-------|
| Student Number/ID | field_XXX | Text | ⚠️ Maybe | If you have a student ID field |
| Date of Birth | field_XXX | Date | ⚠️ Maybe | If available |
| Course | field_XXX | Text | ⚠️ Maybe | Subject/Course enrolled |
| Faculty | field_XXX | Text | ⚠️ Maybe | Faculty/Department |
| Group/Set | field_XXX | Text | ⚠️ Maybe | Teaching group |
| Parent Email | field_XXX | Email | ⚠️ Maybe | For future parent portal |
| Parent Phone | field_XXX | Phone | ⚠️ Maybe | Contact info |

**❓ QUESTION FOR YOU:**
Do you have field IDs for: Student Number, DOB, Course, Faculty, Group, Parent Email/Phone?

---

## 👨‍💼 **Object_5 - Staff Admin**

### **Basic Fields:**

| Knack Field | Field ID | Type | Supabase Column | Priority |
|-------------|----------|------|-----------------|----------|
| Staff Admin Email | field_86 | Email | email | ✅ CRITICAL |
| Name | field_XXX | Name | first_name, last_name, full_name | ✅ CRITICAL |
| Connected Establishment | field_XXX | Connection → Object_2 | school_id | ✅ CRITICAL |
| Phone | field_XXX | Phone | phone_number | ⚠️ IMPORTANT |
| Position/Title | field_XXX | Text | position_title | ⚠️ IMPORTANT |

**❓ QUESTION:** What are the field IDs for Staff Admin name, establishment connection, phone, position?

### **Connection Fields:**

| Knack Field | Field ID | Type | Purpose |
|-------------|----------|------|---------|
| Connected Students | field_XXX | Connection → Object_6 | Many-to-many students |

---

## 👨‍🏫 **Object_7 - Tutor**

### **Basic Fields:**

| Knack Field | Field ID | Type | Supabase Column | Priority |
|-------------|----------|------|-----------------|----------|
| Tutor Email | field_96 | Email | email | ✅ CRITICAL |
| Name | field_XXX | Name | first_name, last_name, full_name | ✅ CRITICAL |
| Connected Establishment | field_XXX | Connection → Object_2 | school_id | ✅ CRITICAL |
| Tutor Group | field_XXX | Text | role_data.tutor_group | ⚠️ IMPORTANT |

**❓ QUESTION:** What are the field IDs for Tutor name, establishment, tutor group?

### **Connection Fields:**

| Knack Field | Field ID | Type | Purpose |
|-------------|----------|------|---------|
| Connected Students | field_XXX | Connection → Object_6 | Tutees (many-to-many) |

---

## 👔 **Object_18 - Head of Year**

### **Basic Fields:**

| Knack Field | Field ID | Type | Supabase Column | Priority |
|-------------|----------|------|-----------------|----------|
| Head of Year Email | field_417 | Email | email | ✅ CRITICAL |
| Name | field_XXX | Name | first_name, last_name, full_name | ✅ CRITICAL |
| Connected Establishment | field_XXX | Connection → Object_2 | school_id | ✅ CRITICAL |
| Year Group Responsible | field_XXX | Text | role_data.year_group | ✅ CRITICAL |

**❓ QUESTION:** What are the field IDs for HOY name, establishment, year group responsibility?

---

## 👨‍🔬 **Object_78 - Subject Teacher**

### **Basic Fields:**

| Knack Field | Field ID | Type | Supabase Column | Priority |
|-------------|----------|------|-----------------|----------|
| Subject Teacher Email | field_1879 | Email | email | ✅ CRITICAL |
| Name | field_XXX | Name | first_name, last_name, full_name | ✅ CRITICAL |
| Connected Establishment | field_XXX | Connection → Object_2 | school_id | ✅ CRITICAL |
| Subject | field_XXX | Text | role_data.subject | ✅ CRITICAL |
| Classes | field_XXX | Text | role_data.classes | ⚠️ IMPORTANT |

**❓ QUESTION:** What are the field IDs for Subject Teacher name, establishment, subject, classes?

---

## 🎯 **What We NEED to Import (Minimum):**

### **Students (Object_6):**
- ✅ field_91 - Email (PRIMARY KEY)
- ✅ field_88 - First Name
- ✅ field_89 - Last Name
- ✅ field_90 - Full Name
- ✅ field_179 - Establishment Connection (for school_id)
- ✅ field_112 - Year Group
- ✅ field_204 - Academic Year
- ✅ field_190 - Connected Staff Admins
- ✅ field_1682 - Connected Tutors
- ✅ field_547 - Connected Heads of Year
- ✅ field_2177 - Connected Subject Teachers

### **Staff (All Objects):**
- ✅ Email field (field_86, field_96, field_417, field_1879)
- ✅ Name fields (need field IDs)
- ✅ Establishment connection (need field IDs)
- ✅ Connected Students (need field IDs)
- ⚠️ Role-specific fields (tutor group, year group, subject, etc.)

---

## 🔍 **How to Get Missing Field IDs:**

Run this in Knack:

**For Students (Object_6):**
```javascript
// In browser console on Knack page
console.log(Knack.objects.getObject('object_6').fields);
```

**Or export from Knack Builder:**
- Go to Knack Builder
- Click on Student object (Object_6)
- Export field list

---

## 📋 **Recommended Import Strategy:**

### **Phase 1 (NOW - Minimum Viable):**
- Core identity: Email, Name
- School: Establishment connection
- Basic info: Year group, Academic year
- Relationships: Staff connections

### **Phase 2 (After Testing):**
- Extended info: Phone, DOB, Student ID
- Course/Faculty/Group data
- Parent contact info

### **Phase 3 (Future):**
- Custom fields per establishment
- SEN information
- Pastoral notes

---

## ✅ **Action Required:**

Please provide field IDs for:

1. **Object_6 (Students):**
   - ❓ field_179 verification (Establishment connection)
   - ❓ Student ID/Number field
   - ❓ Date of Birth field
   - ❓ Course field
   - ❓ Faculty field
   - ❓ Group/Set field

2. **Object_5 (Staff Admin):**
   - ❓ Name field
   - ❓ Establishment connection
   - ❓ Phone field
   - ❓ Connected Students field

3. **Object_7 (Tutor):**
   - ❓ Name field
   - ❓ Establishment connection
   - ❓ Tutor Group field
   - ❓ Connected Students field

4. **Object_18 (Head of Year):**
   - ❓ Name field
   - ❓ Establishment connection
   - ❓ Year Group Responsible field
   - ❓ Connected Students field

5. **Object_78 (Subject Teacher):**
   - ❓ Name field
   - ❓ Establishment connection
   - ❓ Subject field
   - ❓ Classes/Groups field
   - ❓ Connected Students field

---

**Once you provide these field IDs, I'll update the migration script with complete field mappings!**

Alternatively, you can export the field list from Knack Builder and share it with me. 📋
