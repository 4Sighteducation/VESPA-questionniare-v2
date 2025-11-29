# Quick Start Guide: Hybrid Account Migration

**Date**: November 2025  
**Status**: Ready to Execute  
**Test School**: VESPA ACADEMY (ID: `b4bbffc9-7fb6-415a-9a8a-49648995f6b3`)

---

## 🎯 **What We're Doing:**

1. Creating hybrid account architecture (vespa_accounts + vespa_staff)
2. Testing with VESPA ACADEMY first (safe isolated test)
3. Then migrating all 127 schools

---

## 📋 **Execution Steps:**

### **Step 1: Run Database Schema (10 minutes)**

**Open Supabase SQL Editor** → Paste → Run:

```
File: ADDITIVE_HYBRID_MIGRATION.sql
```

**What it does:**
- Creates vespa_accounts (parent table for all users)
- Creates vespa_staff (staff profiles)
- Creates user_roles (multi-role support)
- Creates user_connections (staff ↔ student relationships)
- Links existing 4,834 vespa_students → vespa_accounts
- Adds establishment foreign keys

**Expected output:**
```
✅ Step 1: Created vespa_accounts table
✅ Step 2: Migrated 4834 existing students → vespa_accounts
✅ Step 3a: Added account_id column to vespa_students
✅ Step 3b: Linked 4834 students to accounts
... (continues through Step 10)
```

**Verify:**
```sql
SELECT COUNT(*) FROM vespa_accounts WHERE account_type = 'student';
-- Should return: 4834

SELECT COUNT(*) FROM vespa_students WHERE account_id IS NOT NULL;
-- Should return: 4834
```

---

### **Step 2: Test Migration with VESPA ACADEMY (15 minutes)**

**In terminal:**

```bash
cd C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\VESPAQuestionnaireV2\migration_scripts

python 06_TEST_migrate_vespa_academy.py
```

**What it does:**
- Fetches VESPA ACADEMY students from Knack (Object_6)
- Creates accounts for each student
- Links them to VESPA ACADEMY establishment
- Creates vespa_students entries

**Expected output:**
```
🧪 VESPA ACADEMY TEST MIGRATION
✅ Found X VESPA ACADEMY students in Knack
✅ Migrated: X students
⏭️  Skipped: Y students (already existed)
📊 Migration Summary...
```

**Verify:**
```sql
SELECT COUNT(*) FROM vespa_students 
WHERE school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3';
-- Should match Knack count for VESPA ACADEMY
```

---

### **Step 3: Test Staff Migration (Not Yet Created)**

**Coming next:** Will create staff migration script once student migration is verified.

---

### **Step 4: Test Activities**

1. Log in as VESPA ACADEMY staff member
2. Navigate to activities page
3. Verify you can see VESPA ACADEMY students
4. Assign an activity
5. Log in as VESPA ACADEMY student
6. Complete the activity
7. Verify it saves to Supabase

---

### **Step 5: Full Migration (After Testing)**

Once VESPA ACADEMY works perfectly:

```bash
python 06_migrate_all_active_students.py  # Migrates all 23,717 active students
python 07_migrate_all_staff.py            # Migrates all staff from all schools
```

---

## 🔍 **Verification Queries:**

### **Check Migration Status:**

```sql
-- Overall counts
SELECT 
  'vespa_accounts (students)' as table_name,
  COUNT(*) as total
FROM vespa_accounts WHERE account_type = 'student'
UNION ALL
SELECT 
  'vespa_students',
  COUNT(*)
FROM vespa_students
UNION ALL
SELECT 
  'vespa_staff',
  COUNT(*)
FROM vespa_staff
UNION ALL
SELECT 
  'user_connections',
  COUNT(*)
FROM user_connections;
```

### **Check VESPA ACADEMY Isolation:**

```sql
-- VESPA ACADEMY data
SELECT 
  'VESPA ACADEMY Students' as metric,
  COUNT(*) as count
FROM vespa_students
WHERE school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
UNION ALL
SELECT 
  'VESPA ACADEMY Staff',
  COUNT(*)
FROM vespa_staff
WHERE school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3';
```

### **Check for Data Leakage:**

```sql
-- Verify no cross-establishment connections
SELECT 
  staff.school_name as staff_school,
  student.school_name as student_school,
  COUNT(*) as connection_count
FROM user_connections uc
JOIN vespa_staff staff ON uc.staff_account_id = staff.account_id
JOIN vespa_students student ON uc.student_account_id = student.account_id
WHERE staff.school_id != student.school_id
GROUP BY staff.school_name, student.school_name;
-- Should return 0 rows
```

---

## ⚠️ **If Something Goes Wrong:**

### **Rollback VESPA ACADEMY Migration:**

```sql
-- Delete VESPA ACADEMY students from new tables
DELETE FROM user_connections
WHERE student_account_id IN (
  SELECT account_id FROM vespa_students
  WHERE school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
);

DELETE FROM vespa_students
WHERE school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
AND email NOT IN (
  SELECT email FROM activity_responses  -- Keep students who have activity data
);

DELETE FROM vespa_accounts
WHERE school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
AND account_type = 'student'
AND id NOT IN (
  SELECT account_id FROM vespa_students
);
```

### **Rollback Entire Migration:**

```sql
-- Nuclear option - only if completely broken
DROP TABLE IF EXISTS user_connections CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;
DROP TABLE IF EXISTS vespa_staff CASCADE;

-- Remove account_id from vespa_students
ALTER TABLE vespa_students DROP COLUMN IF EXISTS account_id CASCADE;

-- Remove vespa_accounts
DROP TABLE IF EXISTS vespa_accounts CASCADE;
```

Then start over with Step 1.

---

## 📊 **Current State:**

| Component | Status | Records |
|-----------|--------|---------|
| `establishments` | ✅ Ready | 127 schools |
| `students` (legacy) | ✅ Active | 36,540 students |
| `vespa_students` | ✅ Active | 4,834 students |
| `vespa_accounts` | ⏳ Ready to create | 0 |
| `vespa_staff` | ⏳ Ready to create | 0 |
| `user_connections` | ⏳ Ready to create | 0 |

---

## 🎯 **Target State (After Full Migration):**

| Component | Status | Records |
|-----------|--------|---------|
| `establishments` | ✅ Unchanged | 127 schools |
| `students` (legacy) | ✅ Unchanged | 36,540 (dashboard continues) |
| `vespa_accounts` | ✅ Complete | ~24,000 (students + staff) |
| `vespa_students` | ✅ Complete | ~23,717 (active students) |
| `vespa_staff` | ✅ Complete | ~200-500 staff |
| `user_connections` | ✅ Complete | ~50,000-100,000 connections |

---

## ✅ **Success Criteria:**

- [ ] ADDITIVE_HYBRID_MIGRATION.sql runs without errors
- [ ] 4,834 existing vespa_students linked to vespa_accounts
- [ ] VESPA ACADEMY students migrated successfully
- [ ] VESPA ACADEMY staff can see their students
- [ ] Students can complete activities
- [ ] Data isolated by establishment (no leakage)
- [ ] Ready to migrate all 127 schools

---

## 📞 **Next Conversation:**

After running Steps 1 & 2, share:
1. Any errors from ADDITIVE_HYBRID_MIGRATION.sql
2. Output from 06_TEST_migrate_vespa_academy.py
3. Results from verification queries

Then I'll create:
- Staff migration script
- Full migration scripts
- Onboarding integration guide

---

**Ready to start? Run Step 1!** 🚀

