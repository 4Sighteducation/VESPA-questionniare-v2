# 🚀 Execution Plan: Fix Orphaned Records

**Date**: December 1, 2025  
**Status**: Ready to Execute  
**Estimated Time**: 3-4 hours  
**Risk Level**: Medium

---

## 📋 FILES CREATED

### **Diagnostic Tools**:
1. ✅ `DIAGNOSTIC_SQL_INVESTIGATION.sql` - Comprehensive investigation queries
2. ✅ `ROOT_CAUSE_ANALYSIS.md` - Complete root cause analysis

### **Fix Scripts**:
3. ✅ `fix_orphaned_students.py` - Backfill school_id for orphaned students
4. ✅ `migrate-activity-responses-v2.js` - Backfill empty responses JSONB
5. ✅ `CLEAN_EMAIL_HTML_TAGS.sql` - Clean email HTML tags
6. ✅ `activities_api.py` - Fixed to NOT create orphaned students

---

## 🎯 EXECUTION SEQUENCE

### **PHASE 1: Investigation (15 minutes)**

#### **Step 1.1: Run Diagnostic SQL**
```bash
# Connect to Supabase SQL Editor
# https://supabase.com/dashboard/project/qcdcdzfanrlvdcagmwmg/sql

# Copy and run: DIAGNOSTIC_SQL_INVESTIGATION.sql
# Review results and confirm:
# - Total orphaned students (~4,822)
# - Coffs Harbour showing 4 vs expected 70
# - All activity responses have empty {}
```

**Expected Results**:
- Confirm 19% orphaned rate
- Verify Coffs Harbour has ~70 students with NULL school_id
- Confirm 100% empty responses

#### **Step 1.2: Verify Root Causes**
- Check `knack_user_attributes` contains establishment references
- Verify establishments table has all schools
- Confirm email HTML tag pollution exists

**Checkpoint**: ✅ Investigation confirms root causes → Proceed to Phase 2

---

### **PHASE 2: Deploy Critical Fix (15 minutes)**

#### **Step 2.1: Fix activities_api.py (Prevent Future Orphans)**

```bash
cd /path/to/DASHBOARD

# The file has already been updated with the fix
# Review changes:
git diff activities_api.py

# Commit changes
git add activities_api.py
git commit -m "fix: Prevent activities_api from creating orphaned students

- Remove student creation in ensure_vespa_student_exists()
- Log warning instead when student doesn't exist
- Students should be created by upload system with full data
- Fixes root cause of 19% orphaned students (4,822 records)

Related: ROOT_CAUSE_ANALYSIS.md"

# Deploy to production
git push origin main
# (Or however you deploy the dashboard)
```

**Checkpoint**: ✅ Fix deployed → No more orphans will be created

---

### **PHASE 3: Backfill Orphaned Students (1 hour)**

#### **Step 3.1: Test on Sample (Coffs Harbour)**

```bash
cd /path/to/DASHBOARD

# Dry run on 10 students
python fix_orphaned_students.py --limit 10

# Review output:
# - Check how many matched to establishments
# - Verify school_id and school_name are correct
# - Note any errors
```

**Expected Output**:
```
Found 10 orphaned students
Would fix: 8
No Knack data: 1
Establishment not found: 1
```

#### **Step 3.2: Run on All Orphaned Students**

```bash
# DRY RUN first (full dataset)
python fix_orphaned_students.py

# Review output carefully
# Check success rate (should be >80%)

# If looks good, run LIVE
python fix_orphaned_students.py --live
```

**Expected Results**:
- Fixed: ~4,000 students (80-85%)
- No data: ~500 students (need manual review)
- Est not found: ~300 students (need establishments synced)

#### **Step 3.3: Verify in Account Manager**

```bash
# Open Account Manager for Coffs Harbour
# URL: https://vespaacademy.knack.com/vespa-academy#vespa-account-management/

# Should now see ~70 students instead of 4
```

**Checkpoint**: ✅ Coffs Harbour shows correct count → Proceed to Phase 4

---

### **PHASE 4: Fix Empty Activity Responses (1 hour)**

#### **Step 4.1: Test on Alena Ramsey**

```bash
cd /path/to/vespa-activities-v3/scripts

# Set environment variable
export SUPABASE_SERVICE_KEY="your-service-key"

# Dry run
node migrate-activity-responses-v2.js

# Look for Alena's activities in output
# Check that responses have data
```

**Expected Output**:
```
Knack Object_46 answers: 16,186
Supabase activity_responses: 42,000+
Matched to Knack: ~15,000
Would update: ~15,000
```

#### **Step 4.2: Run LIVE Migration**

```bash
# LIVE RUN
node migrate-activity-responses-v2.js --live
```

**Expected Results**:
- Updated: ~15,000 activity responses
- Empty responses: 0% (down from 100%)

#### **Step 4.3: Verify Alena's Responses**

```sql
-- Run in Supabase SQL Editor
SELECT 
  ar.student_email,
  a.name as activity_name,
  ar.status,
  ar.responses,
  jsonb_object_keys(ar.responses) as response_keys
FROM activity_responses ar
JOIN activities a ON a.id = ar.activity_id
WHERE ar.student_email = 'aramsey@vespa.academy'
  AND ar.status = 'completed'
LIMIT 10;
```

**Expected**: Should see actual response data, not `{}`

**Checkpoint**: ✅ Responses populated → Proceed to Phase 5

---

### **PHASE 5: Clean Email HTML Tags (30 minutes)**

#### **Step 5.1: Run Analysis Section**

```bash
# In Supabase SQL Editor
# Run STEP 1 of CLEAN_EMAIL_HTML_TAGS.sql
```

**Expected Output**:
```
vespa_students: 150 emails with HTML
vespa_accounts: 75 emails with HTML
activity_responses: 200 emails with HTML
```

#### **Step 5.2: Backup and Clean**

```sql
-- Run STEP 4 (Backup)
-- Run STEP 5 (Clean vespa_students)
-- Run STEP 6 (Clean vespa_accounts)
-- Run STEP 7 (Clean activity_responses)
```

#### **Step 5.3: Handle Duplicates**

```sql
-- Run STEP 8 to find duplicates
-- For each duplicate, manually merge using template
```

**Checkpoint**: ✅ No HTML tags remain → Proceed to Phase 6

---

### **PHASE 6: Sync Missing Establishments (15 minutes)**

#### **Step 6.1: Update Sync Script**

```python
# File: DASHBOARD/sync_knack_to_supabase.py
# Line 260-271

# BEFORE:
filters = [
    {
        'field': 'field_2209',
        'operator': 'is not',
        'value': 'Cancelled'
    },
    {
        'field': 'field_63',  # Portal type field
        'operator': 'contains',
        'value': 'COACHING PORTAL'  # ❌ TOO RESTRICTIVE
    }
]

# AFTER:
filters = [
    {
        'field': 'field_2209',
        'operator': 'is not',
        'value': 'Cancelled'
    }
    # ✅ Removed COACHING PORTAL filter - sync ALL active establishments
]
```

#### **Step 6.2: Run One-Time Sync**

```bash
cd /path/to/DASHBOARD

# Run sync to backfill missing establishments
python sync_knack_to_supabase.py --establishments-only

# Or run full sync
python sync_knack_to_supabase.py
```

#### **Step 6.3: Re-run Fix for Remaining Orphans**

```bash
# Some students couldn't be fixed because establishment wasn't synced
# Now that we've synced missing establishments, try again

python fix_orphaned_students.py --live
```

**Checkpoint**: ✅ All establishments synced → Proceed to Phase 7

---

### **PHASE 7: Final Verification (30 minutes)**

#### **Step 7.1: Run Diagnostic SQL Again**

```sql
-- Run summary query from DIAGNOSTIC_SQL_INVESTIGATION.sql
SELECT 
  'Total Students' as metric,
  COUNT(*)::text as value
FROM vespa_students
UNION ALL
SELECT 
  'Orphaned Students (NULL school_id)',
  COUNT(*)::text
FROM vespa_students WHERE school_id IS NULL
UNION ALL
SELECT 
  'Empty Response JSONs',
  COUNT(*)::text
FROM activity_responses WHERE responses = '{}';
```

**Expected Results**:
```
Total Students: 24,923
Orphaned Students: ~500 (down from 4,822)
Empty Responses: 0 (down from ~40,000)
```

#### **Step 7.2: Test Account Manager**

1. ✅ Log in as Coffs Harbour admin
2. ✅ Navigate to Account Management
3. ✅ Verify ~70 students visible (up from 4)
4. ✅ Check students have proper year groups, names, etc.

#### **Step 7.3: Test Activity Dashboard**

1. ✅ Log in as staff member
2. ✅ Open student workspace
3. ✅ Check Alena Ramsey's completed activities
4. ✅ Verify actual responses visible (not empty)

#### **Step 7.4: Check Staff Connections**

```sql
-- Students without connections (should be minimal)
SELECT 
  vs.email,
  vs.school_name,
  COUNT(uc.id) as connection_count
FROM vespa_students vs
LEFT JOIN vespa_accounts va ON va.email = vs.email
LEFT JOIN user_connections uc ON uc.student_account_id = va.id
WHERE vs.school_id IS NOT NULL
GROUP BY vs.email, vs.school_name
HAVING COUNT(uc.id) = 0
LIMIT 50;
```

**Expected**: Minimal students without connections

---

## 📊 EXPECTED BEFORE/AFTER

### **Before Fixes**:
| Metric | Value | Status |
|--------|-------|--------|
| Total Students | 24,923 | ✅ |
| Orphaned (NULL school_id) | 4,822 (19%) | ❌ |
| Coffs Harbour Visible | 4 | ❌ |
| Empty Responses | ~40,000 (100%) | ❌ |
| HTML Tag Emails | ~425 | ⚠️ |

### **After Fixes**:
| Metric | Value | Status |
|--------|-------|--------|
| Total Students | 24,923 | ✅ |
| Orphaned (NULL school_id) | ~500 (2%) | ✅ |
| Coffs Harbour Visible | 70+ | ✅ |
| Empty Responses | 0 (0%) | ✅ |
| HTML Tag Emails | 0 | ✅ |

---

## ⚠️ RISKS & MITIGATION

### **Risk 1: Data Loss During Merge**
**Mitigation**: 
- All scripts create backups before modifying data
- Rollback scripts provided
- Test on small subset first (--limit 10)

### **Risk 2: Script Failures**
**Mitigation**:
- All scripts have error handling
- Continue on error (don't stop processing)
- Detailed error logging
- Can re-run safely (idempotent)

### **Risk 3: Wrong School Assignment**
**Mitigation**:
- Scripts use Knack data (source of truth)
- Manual review of first 10 results
- Dry run mode to preview changes
- Can rollback if needed

### **Risk 4: Production Downtime**
**Mitigation**:
- Scripts run in background (don't block UI)
- No schema changes required
- Can run during business hours
- activities_api.py fix is non-breaking

---

## 🎯 SUCCESS CRITERIA

### **Must Have**:
1. ✅ Orphaned students < 5% (down from 19%)
2. ✅ Coffs Harbour shows correct count
3. ✅ Activity responses have data
4. ✅ No future orphans created

### **Nice to Have**:
1. ✅ All HTML tags cleaned
2. ✅ All orphans fixed (0%)
3. ✅ All establishments synced
4. ✅ No duplicate emails

---

## 📞 NEXT STEPS

1. **NOW**: Run Phase 1 (Investigation - 15 min)
2. **If confirmed**: Run Phase 2 (Deploy fix - 15 min)
3. **Today**: Run Phase 3 (Backfill students - 1 hour)
4. **Today**: Run Phase 4 (Fix responses - 1 hour)
5. **Tomorrow**: Run Phase 5-7 (Cleanup & verification)

---

## 🐛 TROUBLESHOOTING

### **"Establishment not found" errors**
→ Run Phase 6 first (sync missing establishments)

### **"No Knack data" errors**
→ Manual review needed - student might be invalid

### **"Update failed" errors**
→ Check logs for constraint violations
→ May need to fix data manually

### **Script hangs/timeout**
→ Use `--limit` flag to process in batches
→ Can re-run safely (picks up where left off)

---

**Ready to execute!** Start with Phase 1 diagnostic queries. 🚀



