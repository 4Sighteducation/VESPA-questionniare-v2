# VESPA Activities V3 - Migration Scripts

## 🎯 Purpose
Migrate VESPA Activities system from Knack (Objects 44, 45, 46) to Supabase with full data preservation.

## 📋 Prerequisites

1. **Python 3.8+** installed
2. **Supabase project** created with tables from schema
3. **Environment variables** configured (see below)
4. **Network access** to Knack API

## ⚙️ Setup

### 1. Install Python dependencies
```bash
cd migration_scripts
pip install -r requirements.txt
```

### 2. Configure environment variables
Create a `.env` file in this directory:
```bash
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key-here

# Knack Configuration
KNACK_APP_ID=66e26296d863e5001c6f1e09
KNACK_API_KEY=0b19dcb0-9f43-11ef-8724-eb3bc75b770f
```

**⚠️ IMPORTANT**: Use your Supabase **service role key**, not anon key!

---

## 🚀 Migration Sequence (Run in Order)

### **Step 1: Migrate Activities** (75 records)
```bash
python 01_migrate_activities.py
```
**Duration**: ~2 minutes  
**Source**: `vespa-activities-v2/shared/utils/structured_activities_with_thresholds.json`  
**Target**: `activities` table

### **Step 2: Migrate Questions** (1,573 records)
```bash
python 02_migrate_questions.py
```
**Duration**: ~5 minutes  
**Source**: `activityquestion.csv`  
**Target**: `activity_questions` table  
**Note**: Links questions to activities via activity name matching

### **Step 3: Update Problem Mappings**
```bash
python 03_update_problem_mappings.py
```
**Duration**: ~1 minute  
**Source**: `vespa-activities-v2/shared/vespa-problem-activity-mappings1a.json`  
**Target**: Updates `activities.problem_mappings` array

### **Step 4: Migrate Historical Responses** (6,060 records)
```bash
python 04_migrate_historical_responses.py
```
**Duration**: ~15 minutes  
**Source**: Knack Object_46 via API  
**Target**: `activity_responses` + `vespa_students` tables  
**Filters**:
- `field_1870` (completion_date) >= 2025-01-01
- `field_1301` (student_email) IS NOT NULL

### **Step 5: Seed Achievement Definitions**
```bash
python 05_seed_achievements.py
```
**Duration**: ~1 minute  
**Target**: `achievement_definitions` table  
**Creates**: 23 achievement types with gamification rules

---

## 🔍 Verification Queries

After migration, run these in Supabase SQL Editor:

```sql
-- Check activities migrated
SELECT COUNT(*) as total_activities FROM activities;
-- Expected: 75

-- Check questions migrated
SELECT COUNT(*) as total_questions FROM activity_questions;
-- Expected: ~1573

-- Check historical responses
SELECT COUNT(*) as total_responses FROM activity_responses;
-- Expected: ~6060

-- Check unique students created
SELECT COUNT(DISTINCT email) as unique_students FROM vespa_students;
-- Expected: Varies based on data

-- Check achievement definitions
SELECT COUNT(*) as total_achievements FROM achievement_definitions;
-- Expected: 23

-- View activities by category
SELECT vespa_category, level, COUNT(*) as count 
FROM activities 
GROUP BY vespa_category, level 
ORDER BY vespa_category, level;

-- View response completions by month
SELECT DATE_TRUNC('month', completed_at) as month, COUNT(*) as completions
FROM activity_responses
WHERE completed_at IS NOT NULL
GROUP BY month
ORDER BY month DESC;
```

---

## 🛠️ Troubleshooting

### **Problem**: "Module not found: supabase"
**Solution**: Run `pip install -r requirements.txt` again

### **Problem**: "Connection refused" to Supabase
**Solution**: Check SUPABASE_URL is correct and includes `https://`

### **Problem**: "Activity not found in Supabase"
**Solution**: Ensure Step 1 completed successfully before running Step 2

### **Problem**: "Knack API rate limit exceeded"
**Solution**: 
- Wait 1 minute
- Add delay in script: `time.sleep(1)` between requests

### **Problem**: Date parsing errors in Step 4
**Solution**: Script handles multiple date formats automatically. Check error log for specific records.

---

## 📊 Expected Output

### Successful Migration
```
🚀 Starting VESPA Activities Migration - Step 1: Activities
============================================================
📂 Loading activities from: .../structured_activities_with_thresholds.json
📊 Found 75 activities to migrate
✅ [1/75] Migrated: Stopping Negative Thoughts
✅ [2/75] Migrated: Stand Tall
...
✅ [75/75] Migrated: 20 Questions

============================================================
📊 MIGRATION SUMMARY
============================================================
Total activities: 75
Successfully migrated: 75
Errors: 0

✅ All activities migrated successfully!

🎉 Migration Step 1 completed successfully!
➡️  Next: Run 02_migrate_questions.py
```

---

## 🔄 Re-running Migrations

All scripts use **upsert** logic where possible, so they're safe to re-run if errors occur.

**Exception**: Step 4 (historical responses) does NOT upsert. It will create duplicates if re-run. 

**To re-run Step 4**:
```sql
-- First, delete existing responses
DELETE FROM activity_responses WHERE knack_id IS NOT NULL;

-- Then re-run script
python 04_migrate_historical_responses.py
```

---

## 📞 Support

If you encounter errors during migration:
1. Check error messages carefully
2. Verify Supabase connection
3. Check Knack API is accessible
4. Review data integrity in source files

All scripts log errors with details for debugging.

---

**Last Updated**: November 2025  
**Author**: Tony D  
**Status**: Ready for production migration

