# 🚀 Ready to Run - VESPA Academy Test Migration

**Date**: November 2025  
**Status**: ✅ All Scripts Ready  
**Database**: `qcdcdzfanrlvdcagmwmg.supabase.co` (vespa-dashboard)

---

## ✅ **What's Been Completed:**

### **1. Database Schema ✅**
- ✅ vespa_accounts created (4,834 existing students migrated)
- ✅ vespa_staff created (ready for staff)
- ✅ user_roles created (multi-role support)
- ✅ user_connections created (staff ↔ student relationships)
- ✅ Helper functions created (get_or_create_account, etc.)
- ✅ RLS policies enabled
- ✅ All existing vespa_students linked to accounts

---

## 📋 **Next Steps:**

### **Step 1: Update Role Constraints (1 minute)**

**Run in Supabase SQL Editor:**

```
File: UPDATE_ROLE_CONSTRAINTS.sql
```

This adds support for:
- General Staff
- Head of Department  
- Parent (future)

---

### **Step 2: Run VESPA ACADEMY Test Migration (5-10 minutes)**

**In terminal:**

```bash
cd "C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\VESPAQuestionnaireV2\migration_scripts"

python 06_migrate_vespa_academy_COMPLETE.py
```

**What it does:**
1. **Phase 1**: Imports all VESPA ACADEMY accounts from Object_3
   - Creates vespa_accounts for all users
   - Creates vespa_students for users with "Student" role
   - Creates vespa_staff for users with staff roles
   - Creates user_roles for each staff role
   
2. **Phase 2**: Builds connections from Object_6
   - Queries Object_6 for connection fields (field_1682, field_547, field_2177)
   - Creates user_connections for Tutors, HOYs, Subject Teachers
   - Skips Staff Admins (RLS gives them establishment-wide access)

3. **Verification**: Checks data integrity
   - Counts accounts, students, staff
   - Lists roles and connections
   - Checks for orphaned records

---

## 📊 **Expected Results:**

```
🧪 VESPA ACADEMY COMPLETE MIGRATION
✅ Found X VESPA ACADEMY accounts in Knack Object_3
✅ Student: student1@vespa.academy
✅ Staff: teacher@vespa.academy (Tutor, Subject Teacher)
...

📊 Phase 1 Summary:
  Total accounts processed: X
  Students created: Y
  Staff created: Z
  Multi-role accounts: N

📊 Phase 2 Summary:
  Tutor connections: A
  HOY connections: B
  Teacher connections: C
  Total: D

🔍 VERIFICATION
✅ vespa_accounts: X total
✅ vespa_students: Y
✅ vespa_staff: Z
✅ user_connections: D
```

---

## 🎯 **Key Features of This Migration:**

### **1. Object_3 as Primary Source**
- Single API call for all users
- Automatic multi-role detection
- Complete data in one place

### **2. Account Type Normalization**
- "Gold", "Silver", "Bronze", "Coaching" → "COACHING PORTAL"
- "Resource", "Resources" → "RESOURCE PORTAL"
- NULL/blank → "COACHING PORTAL" + flagged for review

### **3. Multi-Role Support**
- One person can be Student + Tutor
- Staff Admin + Head of Year + Subject Teacher
- Each role gets separate user_role entry

### **4. Smart Connection Building**
- **Staff Admins**: No explicit connections (RLS grants establishment access)
- **Tutors/HOY/Teachers**: Explicit connections from Object_6
- Many-to-many supported (student can have multiple tutors)

### **5. Establishment Isolation**
- All data scoped to VESPA ACADEMY
- No cross-school leakage
- RLS enforces at database level

---

## 🔍 **Post-Migration Verification:**

After running the script, verify with this SQL:

```sql
-- VESPA ACADEMY summary
SELECT 
  'Students' as type,
  COUNT(*) as count
FROM vespa_students
WHERE school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
UNION ALL
SELECT 
  'Staff',
  COUNT(*)
FROM vespa_staff
WHERE school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
UNION ALL
SELECT 
  'Connections',
  COUNT(*)
FROM user_connections uc
JOIN vespa_students vs ON uc.student_account_id = vs.account_id
WHERE vs.school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3';

-- Check role distribution
SELECT 
  role_type,
  COUNT(*) as count
FROM user_roles ur
JOIN vespa_accounts va ON ur.account_id = va.id
WHERE va.school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
GROUP BY role_type
ORDER BY count DESC;

-- Check for multi-role users
SELECT 
  va.email,
  va.full_name,
  array_agg(ur.role_type) as roles
FROM vespa_accounts va
JOIN user_roles ur ON va.id = ur.account_id
WHERE va.school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
GROUP BY va.id, va.email, va.full_name
HAVING COUNT(*) > 1
ORDER BY va.email;
```

---

## ⚠️ **Important Notes:**

### **Staff-Staff Connections:**
Currently the script only creates staff → student connections. If you need staff → staff connections (e.g., Tutors connected to their Staff Admin), we can add that in Phase 3.

### **Account Type Review:**
Any accounts flagged for review will be listed in the output. You can manually fix these in Knack field_441.

### **VESPA Scores:**
The migration doesn't touch vespa_scores - that table already works! The activities system will query it by student_email to get scores for activity recommendations.

---

## 🚀 **Ready to Execute:**

**Order:**
1. ✅ ADDITIVE_HYBRID_MIGRATION.sql → **Already run!**
2. **→ UPDATE_ROLE_CONSTRAINTS.sql** → **Run next**
3. **→ 06_migrate_vespa_academy_COMPLETE.py** → **Run last**

After Step 3, you'll have:
- Complete VESPA ACADEMY in Supabase
- All students with proper accounts
- All staff with roles
- All connections established
- Ready to test activities!

---

**Go ahead and run Steps 2 & 3!** 🎯

