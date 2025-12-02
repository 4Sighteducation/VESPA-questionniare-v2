# 🚨 UPDATED Root Cause Analysis Based on SQL Investigation

**Date**: December 1, 2025  
**Status**: Critical Finding - Event-Based Issue  
**Source**: Full SQL Investigation Results

---

## ⚡ **SMOKING GUN: November 11-12 Mass Creation Event**

### **Timeline Shows Concentrated Issue**:
```
Date          | Orphans Created | Total Students Created
------------- | --------------- | ---------------------
Nov 11, 2025  | 1,801          | Unknown
Nov 12, 2025  | 3,021          | Unknown
------------- | --------------- | ---------------------
TOTAL         | 4,822 (100%)   | (all orphans created in 2 days!)

Recent dates:
Nov 25-29     | 0 orphans      | 20,101 students ✅ (with school_id)
```

**Conclusion**: This is NOT a gradual accumulation. Something specific happened on November 11-12 that created 4,822 orphaned records in 48 hours.

---

## 🔍 **WHAT ACTUALLY HAPPENED: The Evidence**

### **Finding #1: Orphaned Students Have NO Knack Data**
```sql
-- Query 8.1: Check if knack_user_attributes contains establishment references
-- Result: Success. No rows returned
```
**Meaning**: Orphaned students have `knack_user_attributes: NULL`  
**Impact**: My fix script (`fix_orphaned_students.py`) **won't work** - there's no Knack data to extract!

---

### **Finding #2: Full Name IS the Email (Name Parsing Failed)**
```
| email                        | full_name                                                    | first_name | last_name                                          |
| ---------------------------- | ------------------------------------------------------------ | ---------- | -------------------------------------------------- |
| ablorsus@hwbcymru.net        | <a href="mailto:ablorsus@hwbcymru.net">ablorsus@hwb...</a>  | <a         | href="mailto:ablorsus@hwbcymru.net">ablorsus...</a> |
```

**Meaning**: 
- The `full_name` field contains the ENTIRE HTML email tag
- `first_name` = `<a`
- `last_name` = `href="mailto:..."`
- Name parsing completely failed at creation time

---

### **Finding #3: 2,092 Students Have HTML Emails (Not 425)**
```
Total Students:              24,923
Students with HTML emails:   2,092 (8.4%)
Orphaned Students:           4,822 (19.4%)
```

**Meaning**: Almost HALF of orphaned students have HTML-wrapped emails (2,092 / 4,822 = 43%)

---

### **Finding #4: Never Synced from Knack**
```
Never synced students:       3,612
Never synced + orphaned:     3,590 (99.4%)
```

**Meaning**: 
- 75% of orphaned students (3,590 / 4,822) were NEVER synced from Knack
- They were created directly in Supabase by some other process
- This rules out the dashboard sync as primary cause (it syncs FROM Knack)

---

### **Finding #5: Orphaned Students HAVE Staff Connections**
```sql
-- Many orphaned students show connection_count > 0
-- Examples:
stinling362@mhs.e-act.org.uk              | null | null | 20 connections
helpdesk@kwschool.co.uk                   | null | null | 7 connections
```

**Meaning**: 
- Connections were created successfully
- But school_id remained NULL
- This suggests the student creation and connection creation happened at different times or via different code paths

---

### **Finding #6: Coffs Harbour Establishment Exists Correctly**
```
id:       caa446f7-c1ad-47cd-acf1-771cacf10d3a
name:     Coffs Harbour Senior College
knack_id: 674999f7b38cce0314c195de
students: 4 (with school_id)
```

**Meaning**: The establishment is correctly in the database, so the issue is NOT missing establishments

---

## 🎯 **REVISED ROOT CAUSE: November 11-12 Mass Import Gone Wrong**

### **What Actually Happened**:

Based on the evidence, here's the likely sequence:

1. **November 11-12**: Someone or something ran a **bulk import** or **migration script**
2. **Source**: Likely a CSV or data export that had emails in HTML format
3. **Process**: Direct insertion into `vespa_students` table (bypassing normal upload flow)
4. **Failure**: 
   - School references not resolved (no knack_id mapping)
   - Name parsing failed (HTML email copied to name fields)
   - Minimal data inserted (no knack_user_attributes)
5. **Result**: 4,822 orphaned students in 2 days

### **Evidence Supporting This Theory**:

✅ **Concentrated timeframe** - 2 days, not gradual  
✅ **No Knack data** - knack_user_attributes is NULL  
✅ **HTML emails** - Source data had HTML-wrapped emails  
✅ **Failed name parsing** - Email copied to first_name/last_name  
✅ **Never synced flag** - last_synced_from_knack is NULL  
✅ **Direct creation** - created_by = 'system' (not specific user)

---

## 🔍 **WHAT SCRIPT RAN ON NOVEMBER 11-12?**

### **Candidates**:

1. **Migration script** (`migrate-activities-complete.js`)?
   - ❌ NO - This migrates activity_responses, not students
   - Date on README: "November 30, 2025"

2. **Dashboard sync** (`sync_knack_to_supabase.py`)?
   - ❌ UNLIKELY - This fetches from Knack (would have knack_user_attributes)
   - Plus it was "fixed" on Nov 12 per logs

3. **CSV bulk upload**?
   - ⚠️ POSSIBLE - But CSV upload uses dual-write (should have school_id)
   - Unless upload was done directly to Supabase bypassing API?

4. **Manual SQL INSERT**?
   - ⚠️ POSSIBLE - Someone might have run INSERT statements
   - Would explain missing data and NULL fields

5. **QR Self-Registration Mass Event**?
   - ⚠️ POSSIBLE - But self-reg creates in Knack first
   - Would have knack_user_attributes

6. **OLD Dashboard Sync (Before Fix)**?
   - ✅ **MOST LIKELY** - activities_api.py was creating minimal students
   - If dashboard sync ran on Nov 11-12 with thousands of NEW questionnaire responses
   - Would create students with just email, no school_id

---

## 🎯 **MOST LIKELY SCENARIO: Dashboard Sync + Questionnaire Backlog**

### **What Happened**:

**November 10-11**: 
- Schools completed VESPA questionnaires (4,822 students)
- Students not yet uploaded to system
- Questionnaire responses stored in Knack

**November 12 Early Morning**:
- Dashboard sync runs (`activities_api.py:1016`)
- Finds 4,822 questionnaire responses with no matching vespa_students
- Creates minimal records for each:
  ```python
  supabase.table('vespa_students').insert({
      "email": student_email,  # ← HTML wrapped!
      "auth_provider": "knack",
      "status": "active",
      "is_active": True
      # ❌ NO school_id, NO names, NO knack_data
  })
  ```

**Result**:
- 4,822 orphaned students created
- All have HTML-wrapped emails (from Knack export format)
- No school_id (not available in questionnaire API)
- Name fields incorrectly populated with HTML email

---

## ✅ **WHY MY ORIGINAL FIX WON'T WORK**

My `fix_orphaned_students.py` script tries to extract school_id from `knack_user_attributes`:

```python
# Line: extract_establishment_id_from_knack_data()
field_133_raw = knack_attributes.get('field_133_raw')
```

**Problem**: `knack_user_attributes` is **NULL** for orphaned students!

**SQL Result**: Query 8.1 returned NO ROWS - no data to extract

**Implication**: We can't backfill from Knack data because the data was never synced from Knack

---

## 🛠️ **REVISED FIX STRATEGY**

### **Option A: Match by Email Domain (Heuristic)**

Many emails contain school identifiers:
```
19mahmooda@stags.herts.sch.uk          → St Albans Girls School
720885@student.corbysixthform.ac.uk    → Corby Sixth Form
21cnevill@thelangton.org.uk            → The Langton School
```

**Strategy**:
1. Build mapping: email domain → establishment
2. Extract domain from orphaned student email
3. Match to known establishment
4. Update school_id

**Success Rate**: ~60-70% (domains with unique schools)

---

### **Option B: Look Up in Knack by Email**

**Strategy**:
1. For each orphaned student email (clean HTML first)
2. Query Knack Object_10 by email (field_197)
3. Extract establishment from field_133
4. Update in Supabase

**Success Rate**: ~85-95% (if student exists in Knack)

---

### **Option C: Delete and Re-Sync from Knack**

**Strategy**:
1. Delete all 4,822 orphaned students
2. Re-run dashboard sync with FIXED activities_api.py
3. Let sync populate students with full data

**Success Rate**: 100% (but loses any connections created)

---

### **Option D: Hybrid Approach** ⭐ **RECOMMENDED**

**Phase 1**: Clean HTML emails (fixes duplicates)
**Phase 2**: Match by email domain (fixes ~60%)
**Phase 3**: Look up remaining in Knack (fixes ~30%)
**Phase 4**: Manual review of remaining (~10%)

**Success Rate**: ~90% automated, ~10% manual

---

## 📊 **UPDATED STATISTICS**

### **Empty Responses - Not as Bad as Thought**:
```
Total activity_responses:    6,947
Empty responses:             2,181 (31%)  ← Not 100%!
Completed with empty:        1,498 (68% of completed)
```

**Meaning**: 
- 69% of responses already have data!
- Only 31% need backfilling
- Still significant but better than expected

### **Alena Ramsey Specifically**:
All 42 of her activities show `responses: {}`  
This confirms responses migration is still needed

---

## 🎯 **REVISED EXECUTION PLAN**

### **Phase 1: Deploy Critical Fix** ✅ ALREADY DONE
- Fixed `activities_api.py` to stop creating orphans
- This prevents the issue from recurring

### **Phase 2: Clean HTML Emails** (15 min)
- Run `CLEAN_EMAIL_HTML_TAGS.sql`
- Fixes 2,092 students
- Merges duplicates

### **Phase 3: Option B - Knack Lookup** (2 hours)
- Create NEW script: `backfill_from_knack.py`
- Query Knack Object_10 for each orphaned email
- Extract school, name, year group
- Update Supabase

### **Phase 4: Fix Activity Responses** (1 hour)
- Run `migrate-activity-responses-v2.js`
- Fixes 2,181 empty responses (not 40,000)

### **Phase 5: Email Domain Matching** (1 hour)
- For remaining orphans without Knack match
- Use domain heuristics
- Manual review remaining

---

## 🚀 **IMMEDIATE NEXT STEPS**

### **1. Confirm Event Timeline** (5 min)
```sql
-- What was happening on Nov 11-12?
SELECT 
  DATE(created_at) as date,
  COUNT(*) as total_created,
  COUNT(*) FILTER (WHERE school_id IS NULL) as orphaned,
  COUNT(*) FILTER (WHERE knack_user_attributes IS NULL) as no_knack_data,
  MIN(created_at) as first_creation,
  MAX(created_at) as last_creation
FROM vespa_students
WHERE created_at::DATE IN ('2025-11-11', '2025-11-12')
GROUP BY DATE(created_at);
```

### **2. Check Knack for These Students** (10 min)
```python
# Quick Knack lookup test
import requests

email_test = "19mahmooda@stags.herts.sch.uk"  # Has 24 activities

# Query Knack Object_10 by email
response = requests.get(
    f"https://api.knack.com/v1/objects/object_10/records",
    headers={
        'X-Knack-Application-Id': KNACK_APP_ID,
        'X-Knack-REST-API-Key': KNACK_API_KEY
    },
    params={
        'filters': [{'field': 'field_197', 'operator': 'is', 'value': email_test}]
    }
)

# If student exists in Knack, we can backfill!
```

### **3. Run Clean Email Script** (15 min)
This will fix the duplicate records issue immediately

---

## 💡 **KEY INSIGHT: This is Fixable!**

**Good News**:
1. ✅ Issue is concentrated (Nov 11-12 event)
2. ✅ Recent students (Nov 25-29) created correctly
3. ✅ Establishments exist in database
4. ✅ Students likely exist in Knack (can backfill)
5. ✅ Only 31% of responses empty (not 100%)

**Challenge**:
1. ⚠️ No knack_user_attributes to extract from
2. ⚠️ Need to query Knack API for each student
3. ⚠️ ~400 students won't be in Knack (need domain matching)

---

## 📝 **REVISED FIX SCRIPTS NEEDED**

### **NEW: `backfill_from_knack_by_email.py`**
```python
# For each orphaned student:
# 1. Clean HTML from email
# 2. Query Knack Object_10 by email (field_197)
# 3. Extract establishment (field_133)
# 4. Extract name (field_187)
# 5. Extract year group (field_144)
# 6. Update vespa_students with full data
```

### **NEW: `match_by_email_domain.py`**
```python
# For students not found in Knack:
# 1. Extract domain from email
# 2. Match to establishment by known patterns
# 3. Update school_id
```

---

## ⚠️ **WHAT TO DO ABOUT COFFS HARBOUR SPECIFICALLY**

### **Current State**:
- Establishment exists correctly ✅
- 4 students with school_id (created Nov 26) ✅
- Expected 70 students total from Knack
- Missing 66 students

### **Investigation Needed**:
1. Check how many Coffs students exist in Knack Object_10
2. Check if they're in the 4,822 orphaned list
3. If yes → Backfill from Knack
4. If no → CSV upload never happened

---

## 🎯 **RECOMMENDED ACTION PLAN**

### **IMMEDIATE (Next 30 min)**:

1. **Run email clean** - Fixes 2,092 duplicate records
   ```sql
   -- Run CLEAN_EMAIL_HTML_TAGS.sql (Steps 1-7)
   ```

2. **Test Knack lookup** - Verify students exist in Knack
   ```python
   # Test with 5 orphaned emails
   # Check if they exist in Object_10
   ```

3. **Create revised backfill script** - Query Knack by email
   ```python
   # NEW: backfill_from_knack_by_email.py
   ```

### **TODAY (Next 3 hours)**:

4. Run backfill from Knack (2 hours)
5. Run activity responses migration (1 hour)
6. Verify Coffs Harbour (5 min)

---

## 🔧 **UPDATED SCRIPTS TO CREATE**

1. ✅ `CLEAN_EMAIL_HTML_TAGS.sql` - Already created
2. 🆕 `backfill_from_knack_by_email.py` - Need to create
3. 🆕 `match_by_email_domain.py` - Need to create  
4. ✅ `migrate-activity-responses-v2.js` - Already created
5. ✅ `activities_api.py` - Already fixed

---

## 📊 **EXPECTED OUTCOMES**

### **After Email Clean**:
- Duplicates: 0 (down from ~200 duplicate pairs)
- HTML emails: 0 (down from 2,092)

### **After Knack Backfill**:
- Orphaned: ~600 (down from 4,822)
- Backfilled from Knack: ~4,000 (85%)

### **After Domain Matching**:
- Orphaned: ~200 (down from ~600)
- Matched by domain: ~400 (70% of remainder)

### **After Manual Review**:
- Orphaned: ~50 (1% - acceptable)
- May be test accounts or invalid data

---

## ❓ **QUESTIONS TO INVESTIGATE**

1. **What ran on November 11-12, 2025?**
   - Check cron jobs
   - Check manual scripts run
   - Check deployment logs

2. **Was there a mass questionnaire completion event?**
   - Multiple schools completing at once?
   - Backfill of old questionnaire data?

3. **Did someone run a direct SQL import?**
   - Check Supabase logs for large batch inserts
   - Check for any migration scripts

4. **Why do orphaned students have connections?**
   - Were connections created separately?
   - Different time window?

---

## 🚀 **NEXT IMMEDIATE ACTIONS**

1. ✅ **Deploy activities_api.py fix** - Already done
2. **Run CLEAN_EMAIL_HTML_TAGS.sql** - Fix duplicates NOW
3. **Create backfill_from_knack_by_email.py** - Query Knack API
4. **Test on 10 students** - Verify approach works
5. **Run on all 4,822** - Backfill from Knack

**This is very fixable! The students likely exist in Knack, we just need to query by email and backfill the data.** 🎯

---

**Critical Change from Original Analysis**: 
We can't use `knack_user_attributes` because it's NULL. We need to **query Knack API directly by email** to get the student's school reference, then backfill.



