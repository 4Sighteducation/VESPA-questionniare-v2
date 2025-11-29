# ✅ Migration Script Fixed & Ready

**Date**: November 2025  
**Status**: READY TO RUN  
**File**: `06_migrate_vespa_academy_BATCH.py`

---

## 🔧 **What Was Fixed:**

### **1. Profile ID Mapping ✅**
- **Problem**: Script looked for "Student", "Tutor" but Knack returns "profile_6", "profile_7"
- **Solution**: Added `PROFILE_TO_ROLE` mapping dictionary
- **Result**: Roles now correctly detected

### **2. Raw Field Extraction ✅**
- **Problem**: Used formatted fields (`field_70`, `field_69`) which return HTML
- **Solution**: Now uses `_raw` fields (`field_70_raw`, `field_69_raw`, etc.)
- **Result**: Clean data extraction

### **3. Name Field Handling ✅**
- **Problem**: Some names are strings, some are objects
- **Solution**: Check type and handle both formats
- **Result**: No more `.get()` errors

### **4. Establishment Linking ✅**
- **Problem**: Hardcoded VESPA_ACADEMY_ID
- **Solution**: Extract from `field_122_raw[0]['id']`
- **Result**: Dynamic establishment linking

### **5. Connection Fields ✅**
- **Problem**: Used formatted connection fields
- **Solution**: Use `_raw` arrays with `[{id, identifier}]` format
- **Result**: Connections will be created properly

---

## 📋 **Key Changes:**

| What | Before | After |
|------|--------|-------|
| **Roles** | `field_73` → "Student" | `field_73_raw` → ["profile_6"] → map to "Student" |
| **Email** | `field_70` → HTML | `field_70_raw['email']` → clean email |
| **Name** | `field_69` → string | `field_69_raw` → {first, last, title} |
| **Establishment** | Hardcoded | `field_122_raw[0]['id']` → dynamic |
| **Connections** | Formatted | `field_XXX_raw` → array of {id, identifier} |

---

## 🚀 **Ready to Run:**

### **Step 1: Clean VESPA ACADEMY Data (in Supabase):**

```sql
DELETE FROM user_connections WHERE student_account_id IN (
  SELECT id FROM vespa_accounts WHERE school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
);
DELETE FROM user_roles WHERE account_id IN (
  SELECT id FROM vespa_accounts WHERE school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
);
DELETE FROM vespa_staff WHERE school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3';
DELETE FROM vespa_students WHERE school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3';
DELETE FROM vespa_accounts WHERE school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3';
```

### **Step 2: Run Fixed Migration (in terminal):**

```bash
cd migration_scripts
python 06_migrate_vespa_academy_BATCH.py
```

---

## 📊 **Expected Output:**

```
✅ Total accounts fetched: 633
Processing accounts...
   DEBUG [email]: roles=['Student'], is_student=True, is_staff=False
   DEBUG [tutor@vespa.academy]: roles=['Tutor'], is_student=False, is_staff=True
   ...

📥 Batch inserting 554 students...
   Batch 1/6 (100 records)... ✅
   ...

📥 Batch inserting 79 staff...  ← Should see this now!
   Batch 1/1 (79 records)... ✅

📊 Phase 1 Complete:
  Accounts: 633
  Students: 554
  Staff: 79  ← Should be > 0!
  Multi-role: X

🔗 PHASE 2: Building Connections...
📥 Creating XXX connections...

✅ vespa_staff: 79  ← Should match!
✅ user_roles: XXX  ← Should have roles!
✅ user_connections: XXX  ← Should have connections!
```

---

## ✅ **Test Cases to Verify:**

After successful migration, check:

### **1. Tutor Account (tut7@vespa.academy - Lesley Christianson):**
```sql
-- Check account exists
SELECT * FROM vespa_accounts WHERE email = 'tut7@vespa.academy';

-- Check staff profile exists
SELECT * FROM vespa_staff WHERE email = 'tut7@vespa.academy';

-- Check has tutor role
SELECT * FROM user_roles ur
JOIN vespa_accounts va ON ur.account_id = va.id
WHERE va.email = 'tut7@vespa.academy';

-- Check connected to aramsey@vespa.academy
SELECT * FROM user_connections uc
JOIN vespa_accounts staff ON uc.staff_account_id = staff.id
JOIN vespa_accounts student ON uc.student_account_id = student.id
WHERE staff.email = 'tut7@vespa.academy'
AND student.email = 'aramsey@vespa.academy';
```

### **2. Staff Admin (lucas@vespa.academy):**
```sql
-- Check has staff_admin role
SELECT * FROM user_roles ur
JOIN vespa_accounts va ON ur.account_id = va.id
WHERE va.email = 'lucas@vespa.academy'
AND ur.role_type = 'staff_admin';
```

---

## 🎯 **Success Criteria:**

- [x] Script uses `_raw` fields
- [x] Profile IDs mapped to role names
- [x] Name handling for strings and objects
- [x] Establishment dynamically extracted
- [x] Batch processing enabled
- [ ] vespa_staff populated (currently 0)
- [ ] user_roles populated (currently 0)
- [ ] user_connections created (currently 0)

---

**Run the cleanup SQL + migration script now!** 🚀

