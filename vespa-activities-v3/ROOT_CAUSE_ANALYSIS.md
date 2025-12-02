# 🚨 Root Cause Analysis: 19% Orphaned Student Records

**Date**: December 1, 2025  
**Status**: Critical Issue Identified  
**Impact**: 4,822 out of 24,923 students (19%) have NULL school_id and school_name

---

## 📊 SUMMARY OF ISSUES

### **Issue 1: Orphaned Students (4,822 records)**
- **Symptom**: 19% of students have `school_id: NULL` and `school_name: NULL`
- **Impact**: These students are invisible in Account Manager (filtered by school)
- **Example**: Coffs Harbour shows 4 students in UI but has ~70 in Knack

### **Issue 2: Empty Activity Responses (ALL records)**
- **Symptom**: ALL activity_responses have `responses: {}` (empty JSONB)
- **Impact**: Students' actual answers are missing despite activities marked completed
- **Cause**: Migration script didn't copy Knack `field_1300` → Supabase `responses`

### **Issue 3: Email HTML Tags**
- **Symptom**: Some emails stored as `<a href="mailto:email@...">email@...</a>`
- **Impact**: Lookup failures, duplicate records, connection failures
- **Source**: Knack wraps connection field emails in HTML anchor tags

---

## 🔍 ROOT CAUSE ANALYSIS

## **ROOT CAUSE #1: Dashboard Sync Creates Students WITHOUT school_id**

### **Location**: `DASHBOARD/activities_api.py:1016`

```python
# LINE 1016-1021: PROBLEM CODE
supabase.table('vespa_students').insert({
    "email": student_email,
    "auth_provider": "knack",
    "status": "active",
    "is_active": True
    # ❌ NO SCHOOL_ID!
    # ❌ NO SCHOOL_NAME!
    # ❌ NO FULL_NAME!
}).execute()
```

**What Happens**:
1. Dashboard sync (daily cron) syncs questionnaire responses
2. When student doesn't exist, it creates a minimal record
3. **Missing fields**: `school_id`, `school_name`, `full_name`, `first_name`, `last_name`
4. Student becomes **orphaned** - visible to nobody!

**Why This Happens**:
- The `activities_api.py` is a lightweight API for questionnaire responses
- It doesn't have access to Knack establishment mappings
- It creates students "just in time" to insert responses
- **It was never designed to be the source of truth for student data**

**Expected Flow**:
1. ✅ Upload system creates student with full data (school_id, names, etc.)
2. ✅ Dashboard sync finds student and adds questionnaire data
3. ✅ Activities API reads student (already exists with school)

**Actual Broken Flow**:
1. ❌ Student completes questionnaire BEFORE being uploaded
2. ❌ Dashboard sync runs → Student doesn't exist
3. ❌ Creates minimal student record (NO school_id!)
4. ❌ Later, upload system tries to create student → Already exists
5. ❌ Student remains orphaned forever

---

## **ROOT CAUSE #2: Upload System Fails Silently on Establishment Lookup**

### **Location**: `vespa-upload-api/src/services/supabaseService.js:179-184`

```javascript
// Look up the establishments UUID from Knack customer ID
const schoolId = await getEstablishmentUuid(knackCustomerId);

if (!schoolId) {
  throw new Error(`Could not find establishment UUID for Knack ID: ${knackCustomerId}`);
}
```

**What Happens**:
1. Upload system receives CSV with student data
2. Tries to map Knack customer ID → `establishments.id` (UUID)
3. **If mapping fails** → Throws error
4. **Worker catches error** → Logs but continues
5. Student gets created in Knack but NOT in Supabase
6. Result: Knack has 70 students, Supabase has 4

**Why Mapping Fails**:
- Establishment not in `establishments` table (wasn't synced)
- Establishment was synced but with different `knack_id` format
- Establishment was created after dual-write was enabled
- Wrong Knack customer ID passed in context

**Evidence from Code**:
```javascript
// From worker.js (assumed behavior based on dual-write docs)
try {
  await syncStudentToSupabase({...});
} catch (error) {
  // ❌ LOGS ERROR BUT CONTINUES!
  console.error('[DUAL-WRITE WARNING] Supabase sync failed:', error.message);
  // Student created in Knack successfully, Supabase fails silently
}
```

---

## **ROOT CAUSE #3: Migration Script Didn't Copy Response Data**

### **Location**: `vespa-activities-v3/scripts/migrate-activities-complete.js:408-410`

```javascript
responses: answerRecord?.field_1300 ? 
  (typeof answerRecord.field_1300 === 'string' ? JSON.parse(answerRecord.field_1300) : answerRecord.field_1300) : 
  {},  // ❌ DEFAULTS TO EMPTY OBJECT!
```

**What Happens**:
1. Migration script reads Object_126 (Activity Progress)
2. Tries to merge with Object_46 (Activity Answers)
3. **Lookup key**: `${studentEmail}_${activityName}` (line 268)
4. **Problem**: If lookup fails → `answerRecord` is `undefined`
5. **Result**: `responses: {}`  (empty)

**Why Lookup Fails**:
- Student email has HTML tags in one object but not the other
- Activity name doesn't match exactly (case, spacing, HTML)
- Object_46 record exists but with different student/activity reference
- Object_46 wasn't fetched completely (pagination issue)

**Evidence**:
- ALL checked students have `responses: {}`
- Activities marked `completed` but no actual student work
- Migration script line 269: `answersMap[key] = answer;` - case-sensitive match!

---

## **ROOT CAUSE #4: Email HTML Tag Pollution**

### **Location**: Multiple (Knack exports, migration scripts, APIs)**

**What Happens**:
Knack wraps connection field emails in HTML:
```html
<!-- Knack exports connection fields like this: -->
<a href="mailto:student@school.com">student@school.com</a>
```

**Where This Causes Problems**:

1. **Dashboard Sync** (`sync_knack_to_supabase.py:221-234`):
   ```python
   def extract_email_from_html(html_or_email):
       if '<a href="mailto:' in str(html_or_email):
           match = re.search(r'mailto:([^"]+)"', str(html_or_email))
           if match:
               return match.group(1)
       return str(html_or_email).strip()
   ```
   ✅ **Has extractor** but may not be used everywhere

2. **Upload System** (`supabaseService.js:85-129`):
   ```javascript
   function extractEmailFromKnack(emailField) {
     if (typeof emailField === 'string' && emailField.includes('<')) {
       const mailtoMatch = emailField.match(/mailto:([^"'>]+)/);
       if (mailtoMatch) {
         return mailtoMatch[1].trim();
       }
     }
   }
   ```
   ✅ **Has extractor** (recently added Nov 27)

3. **Migration Script** (`migrate-activities-complete.js:85-117`):
   ```javascript
   function extractEmail(emailField) {
     // Helper to clean HTML tags from any email string
     const cleanEmail = (str) => {
       if (!str || typeof str !== 'string') return null;
       return str.replace(/<[^>]*>/g, '').trim() || null;
     };
   }
   ```
   ⚠️ **Has cleaner** but may miss some formats

**Result**:
- Some students stored with HTML email: `<a href="mailto:x@y.com">x@y.com</a>`
- Lookups fail: `student@school.com` !== `<a href="mailto:student@school.com">...`
- Creates duplicates OR missing connections

---

## **ROOT CAUSE #5: Incomplete Establishment Sync**

### **Location**: `DASHBOARD/sync_knack_to_supabase.py:236-319`

```python
def sync_establishments():
    # Filter out cancelled establishments AND resource portals
    # Only sync COACHING PORTAL establishments
    filters = [
        {
            'field': 'field_2209',
            'operator': 'is not',
            'value': 'Cancelled'
        },
        {
            'field': 'field_63',  # Portal type field
            'operator': 'contains',
            'value': 'COACHING PORTAL'
        }
    ]
```

**What Happens**:
1. Dashboard sync only syncs **active COACHING PORTAL** establishments
2. Some schools might be:
   - Not marked as "COACHING PORTAL" in Knack
   - Marked as cancelled but still have students
   - Created after last dashboard sync
   - Have typos in portal type field

**Result**:
- Upload system tries to look up `establishments` by `knack_id`
- Establishment not found → `getEstablishmentUuid()` returns `null`
- Student creation fails → Orphaned or not created

---

## 📋 TIMELINE OF HOW RECORDS BECAME ORPHANED

### **Scenario A: Student Completes Questionnaire Before Upload**
```
Day 1: Student registers via QR code → Creates in Knack
Day 2: Student completes VESPA questionnaire
Day 2: Dashboard sync runs (midnight)
       └─> Student not in Supabase yet
       └─> Creates minimal record: { email, is_active: true }
       └─> ❌ NO school_id, NO school_name, NO full_name
Day 3: School uploads student CSV
       └─> Dual-write tries to create in Supabase
       └─> Email already exists → UPSERT updates some fields
       └─> ❌ BUT school_id remains NULL (upsert doesn't override?)
Day 4: Account Manager loads → Filters by school_id
       └─> Student not visible (school_id: NULL)
```

### **Scenario B: Establishment Not Synced**
```
Day 1: New school signs up in Knack
Day 1: Dashboard sync runs
       └─> Syncs only COACHING PORTAL establishments
       └─> New school not marked correctly → Skipped
Day 2: School uploads 70 students via CSV
       └─> Dual-write uploads to Knack ✅
       └─> Dual-write tries Supabase:
           └─> getEstablishmentUuid(knackCustomerId) → NULL
           └─> Throws error: "Could not find establishment UUID"
           └─> Worker catches error, logs, continues
       └─> Result: 70 students in Knack, 0 in Supabase
Day 3: Students complete questionnaires
Day 3: Dashboard sync runs
       └─> Creates 70 minimal students (NO school_id)
Day 4: Account Manager shows 0 students (or orphans)
```

### **Scenario C: Upload System Silent Failure**
```
Day 1: CSV upload with student data
Day 1: Worker creates Object_3, Object_10, Object_29 in Knack ✅
Day 1: Worker calls syncStudentToSupabase()
       └─> getEstablishmentUuid() fails
       └─> Throws error
       └─> Worker catches: "[DUAL-WRITE WARNING] Supabase sync failed"
       └─> Continues to next student
Day 1: Upload completes: "Successfully uploaded 70 students" (Knack only)
Day 2: Dashboard sync creates minimal records (NO school_id)
```

---

## 🎯 WHY COFFS HARBOUR SHOWS 4 STUDENTS INSTEAD OF 70

**Expected**: 70 students in Knack → 70 students in Supabase  
**Actual**: 4 students visible in Account Manager

**Explanation**:

1. **Coffs Harbour** uploaded 70 students via CSV
2. **Dual-write failed** for establishment lookup (Scenario B above)
3. **Dashboard sync** created 70 minimal students (NO school_id)
4. **Later**, 4 students were:
   - Re-uploaded with correct establishment mapping, OR
   - Manually fixed with school_id, OR
   - Created via different flow that worked

5. **Account Manager** filters:
   ```sql
   SELECT * FROM vespa_students
   WHERE school_id = 'coffs-harbour-uuid'
   ```
   Result: Only 4 students (66 orphaned)

---

## ✅ VERIFICATION QUERIES (Run These First!)

```sql
-- 1. Verify Coffs Harbour establishment exists
SELECT id, name, knack_id 
FROM establishments 
WHERE name ILIKE '%coffs%';

-- 2. Count Coffs students (by name)
SELECT COUNT(*) 
FROM vespa_students 
WHERE school_name ILIKE '%coffs%';

-- 3. Count Coffs students (by school_id)
SELECT COUNT(*) 
FROM vespa_students 
WHERE school_id = 'UUID_FROM_QUERY_1';

-- 4. Find orphaned Coffs students
SELECT email, full_name, school_id, school_name, created_at
FROM vespa_students
WHERE (school_name ILIKE '%coffs%' AND school_id IS NULL)
   OR (school_id IS NULL AND email LIKE '%coffs%');

-- 5. Check knack_user_attributes for school reference
SELECT 
  email,
  school_id,
  knack_user_attributes->'field_133_raw'->0->>'id' as knack_establishment_id
FROM vespa_students
WHERE school_id IS NULL
  AND knack_user_attributes IS NOT NULL
LIMIT 10;
```

---

## 🛠️ FIXES REQUIRED

### **Fix 1: Update activities_api.py to Include School Data**
**Priority**: CRITICAL  
**File**: `DASHBOARD/activities_api.py:1016`

```python
# BEFORE (line 1016):
supabase.table('vespa_students').insert({
    "email": student_email,
    "auth_provider": "knack",
    "status": "active",
    "is_active": True
}).execute()

# AFTER:
# Don't create students here AT ALL!
# Instead, require student to exist first (fail gracefully)
try:
    student = supabase.table('vespa_students')\
        .select('id')\
        .eq('email', student_email)\
        .single()\
        .execute()
    
    if not student.data:
        logging.warning(f"Student {student_email} not found - skipping response insert")
        return  # Don't create orphaned record
except Exception as e:
    logging.error(f"Student lookup failed: {e}")
    return
```

### **Fix 2: Add Backfill Script to Fix Orphaned Records**
**Priority**: CRITICAL  
**File**: NEW `fix_orphaned_students.py`

Strategy:
1. Find all students with `school_id: NULL`
2. Check `knack_user_attributes` for establishment reference
3. Look up establishment UUID from `establishments` table
4. Update `vespa_students` with correct `school_id` and `school_name`

### **Fix 3: Re-run Activity Responses Migration**
**Priority**: HIGH  
**File**: NEW `migrate_activity_responses_v2.js`

Strategy:
1. Fetch ALL Object_46 records (Activity Answers)
2. For each activity_response in Supabase:
   - Find matching Object_46 record by student email + activity
   - Update `responses` JSONB from Knack `field_1300`
   - Update `responses_text` from Knack `field_2334`

### **Fix 4: Clean Email HTML Tags**
**Priority**: MEDIUM  
**File**: NEW `clean_email_html_tags.sql`

Strategy:
1. Find all emails with HTML tags
2. Extract clean email using regex
3. Update records with clean email
4. Merge duplicates (same clean email)

### **Fix 5: Sync Missing Establishments**
**Priority**: CRITICAL  
**File**: `DASHBOARD/sync_knack_to_supabase.py`

Strategy:
1. Remove "COACHING PORTAL" filter (sync ALL active establishments)
2. Run one-time sync to backfill missing schools
3. Verify all schools in Knack exist in `establishments`

---

## 📊 EXPECTED RESULTS AFTER FIXES

### **Before**:
- Total students: 24,923
- Orphaned: 4,822 (19%)
- Coffs Harbour visible: 4
- Empty responses: 100%

### **After**:
- Total students: 24,923
- Orphaned: 0 (0%)
- Coffs Harbour visible: 70+
- Empty responses: 0% (backfilled from Knack)

---

## 🚀 EXECUTION PLAN

### **Phase 1: Investigation (15 min)**
1. ✅ Run diagnostic SQL queries
2. ✅ Verify root causes
3. ✅ Check Coffs Harbour specifically

### **Phase 2: Quick Wins (30 min)**
1. Fix `activities_api.py` (prevent future orphans)
2. Sync missing establishments (backfill)
3. Deploy both fixes

### **Phase 3: Backfill Orphaned Records (1 hour)**
1. Create `fix_orphaned_students.py`
2. Run on test subset (10 students)
3. Verify in Account Manager
4. Run on all 4,822 students

### **Phase 4: Fix Activity Responses (1 hour)**
1. Create `migrate_activity_responses_v2.js`
2. Test on Alena Ramsey (42 activities)
3. Run on all students

### **Phase 5: Clean Email HTML (30 min)**
1. Create `clean_email_html_tags.sql`
2. Test on sample
3. Run on all records

### **Phase 6: Verification (30 min)**
1. Re-run diagnostic SQL
2. Check Coffs Harbour in Account Manager
3. Verify Alena's responses show actual answers
4. Test staff connections work

---

## 📞 NEXT STEPS

1. **Run diagnostic SQL** (`DIAGNOSTIC_SQL_INVESTIGATION.sql`)
2. **Review results** and confirm root causes
3. **Create fix scripts** (starting with critical fixes)
4. **Test on small subset** (VESPA ACADEMY or Coffs Harbour)
5. **Roll out fixes** incrementally

**Estimated Total Time**: 3-4 hours  
**Risk Level**: Medium (backfilling data always has risks)  
**Recommendation**: Start with Coffs Harbour as test case

---

**Let's start with Phase 1: Running the diagnostic SQL to confirm these root causes!** 🔍



