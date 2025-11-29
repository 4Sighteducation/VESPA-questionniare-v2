# ✅ Pre-Migration Checklist

**Date**: November 2025  
**Status**: Ready to Run

---

## ✅ **Table Name Verification**

All scripts verified against `FUTURE_READY_SCHEMA.sql`:

| Script | Table(s) Used | Status |
|--------|---------------|--------|
| 01_migrate_activities.py | `activities` | ✅ CORRECT |
| 02_migrate_questions.py | `activities`, `activity_questions` | ✅ CORRECT |
| 03_update_problem_mappings.py | `activities` | ✅ CORRECT |
| 04_migrate_historical_responses.py | `activities`, `vespa_students`, `activity_responses` | ✅ CORRECT |
| 05_seed_achievements.py | `achievement_definitions` | ✅ CORRECT |

**Key Fix**: Script 4 now uses `vespa_students` (not `students`) ✅

---

## ✅ **Environment Variables**

- **.env Location**: `C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\DASHBOARD\DASHBOARD\.env`
- **All scripts updated** to load from this path ✅
- **Required Variables**:
  - `SUPABASE_URL` ✅
  - `SUPABASE_SERVICE_KEY` ✅ (Service Role Key, not anon key)
  - `KNACK_APP_ID` ✅
  - `KNACK_API_KEY` ✅

---

## ✅ **Schema Verification**

Tables created from `FUTURE_READY_SCHEMA.sql`:
- ✅ `activities` (75 records expected)
- ✅ `activity_questions` (~1,573 records expected)
- ✅ `vespa_students` (created during migration)
- ✅ `activity_responses` (~6,060 records expected)
- ✅ `achievement_definitions` (23 records expected)

---

## ✅ **Data Source Files**

- ✅ `structured_activities_with_thresholds.json` - Located in `vespa-activities-v2/shared/utils/`
- ✅ `activityquestion.csv` - Located in project root
- ✅ `vespa-problem-activity-mappings1a.json` - Located in `vespa-activities-v2/shared/`
- ✅ Knack API - Object_46 (historical responses)

---

## 🚀 **Ready to Run**

All checks complete! Migration scripts are ready to execute.

**Run Order**:
1. `python 01_migrate_activities.py`
2. `python 02_migrate_questions.py`
3. `python 03_update_problem_mappings.py`
4. `python 04_migrate_historical_responses.py`
5. `python 05_seed_achievements.py`

**Total Time**: ~25 minutes

---

**Last Verified**: November 2025


