# Re-Run Migrations After Knack Cleanup

## Current Status
- ✅ Beautiful UI deployed (version 1g)
- ✅ Backend API working (Heroku v371)
- ✅ 1,000 historical responses imported (page 1 only)
- ⏳ Knack cleanup running (deleting pre-2025 records)

## Missing Data
- ❌ ~5,000-19,000 historical responses from pages 2-6065
- ❌ aramsey@vespa.academy's 18 valid responses from 2025

## After Knack Cleanup Finishes

### Step 1: Re-run Historical Responses Migration (Script 04)
```bash
cd migration_scripts
python 04_migrate_historical_responses.py
```

**What it will do:**
- Re-process ALL Object_46 records since 2025-01-01
- Use `.upsert()` (won't duplicate existing 1,000 records)
- Import remaining ~19K records
- Should take 30-45 minutes

**Expected result:**
- ~6,000 total records in `activity_responses`
- aramsey's 18 valid responses imported
- All students see their historical completion data

### Step 2: Re-run Student Activities Migration (Script 06)
```bash
cd migration_scripts
python 06_migrate_student_activities.py
```

**What it will do:**
- Re-sync field_1683 (prescribed activities)
- Re-sync field_1380 (finished activities)
- Update after Knack cleanup
- Use `.upsert()` (safe to re-run)

**Expected result:**
- Clean assignment data
- Completion statuses updated
- All students see correct activity lists

### Step 3: Test the App
1. Hard refresh browser (Ctrl+Shift+R)
2. Login as aramsey@vespa.academy
3. Should see:
   - Activities with completion history
   - Saved question answers
   - Staff feedback (if any)

## Verification Queries

After migrations complete, run:
```bash
python check_migration_results.py
```

Or in Supabase SQL editor:
```sql
-- Check aramsey's data
SELECT COUNT(*) FROM activity_responses WHERE student_email = 'aramsey@vespa.academy';
-- Should be ~18

SELECT COUNT(*) FROM student_activities WHERE student_email = 'aramsey@vespa.academy';
-- Should be 3-10 (depending on current assignments)
```

## Notes
- Both scripts are now safe to re-run (use upsert)
- No duplicates will be created
- Can be interrupted and resumed
- Progress shown with page numbers

