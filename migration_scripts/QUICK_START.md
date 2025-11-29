# 🚀 Quick Start Guide - Data Migration to Supabase

**Status**: ✅ SQL Schema Complete - Ready to Import Data

---

## ⚡ **Quick Setup (5 minutes)**

### **1. Install Python Dependencies**
```bash
cd migration_scripts
pip install -r requirements.txt
```

### **2. Create `.env` File**
Create a `.env` file in the `migration_scripts` folder:

```bash
# Supabase Configuration
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key-here

# Knack Configuration (already set)
KNACK_APP_ID=66e26296d863e5001c6f1e09
KNACK_API_KEY=0b19dcb0-9f43-11ef-8724-eb3bc75b770f
```

**⚠️ IMPORTANT**: 
- Get your Supabase URL from: Supabase Dashboard → Settings → API
- Get your **Service Role Key** (NOT anon key) from: Supabase Dashboard → Settings → API → Service Role Key
- The service role key bypasses RLS and is needed for migrations

---

## 📦 **Run Migrations (In Order)**

### **Step 1: Activities** (~2 minutes)
```bash
python 01_migrate_activities.py
```
**Expected**: 75 activities migrated

### **Step 2: Questions** (~5 minutes)
```bash
python 02_migrate_questions.py
```
**Expected**: ~1,573 questions migrated

### **Step 3: Problem Mappings** (~1 minute)
```bash
python 03_update_problem_mappings.py
```
**Expected**: Problem mappings updated for activities

### **Step 4: Historical Responses** (~15 minutes)
```bash
python 04_migrate_historical_responses.py
```
**Expected**: ~6,060 responses migrated (since Jan 2025)

### **Step 5: Achievement Definitions** (~1 minute)
```bash
python 05_seed_achievements.py
```
**Expected**: 23 achievement types created

---

## ✅ **Verify Migration**

Run these queries in Supabase SQL Editor:

```sql
-- Check counts
SELECT COUNT(*) as activities FROM activities;           -- Expected: 75
SELECT COUNT(*) as questions FROM activity_questions;    -- Expected: ~1573
SELECT COUNT(*) as responses FROM activity_responses;    -- Expected: ~6060
SELECT COUNT(*) as achievements FROM achievement_definitions; -- Expected: 23

-- Check activities by category
SELECT vespa_category, level, COUNT(*) 
FROM activities 
GROUP BY vespa_category, level 
ORDER BY vespa_category, level;

-- Check recent responses
SELECT COUNT(*) as recent_responses
FROM activity_responses
WHERE completed_at >= '2025-01-01';
```

---

## 🐛 **Troubleshooting**

### **"Module not found: supabase"**
```bash
pip install -r requirements.txt
```

### **"Connection refused" or "Invalid API key"**
- Check `.env` file exists in `migration_scripts` folder
- Verify SUPABASE_URL includes `https://`
- Verify SUPABASE_SERVICE_KEY is the **service role key** (not anon key)

### **"Activity not found" in Step 2**
- Ensure Step 1 completed successfully first
- Check that activities table has 75 records

### **"Knack API rate limit"**
- Wait 1 minute and retry
- Script handles pagination automatically

---

## 📊 **Expected Output**

Each script will show:
```
🚀 Starting VESPA Activities Migration - Step X: ...
============================================================
📂 Loading data from: ...
📊 Found X records to migrate
✅ [1/X] Migrated: ...
...
✅ [X/X] Migrated: ...

============================================================
📊 MIGRATION SUMMARY
============================================================
Total: X
Successfully migrated: X
Errors: 0

✅ All records migrated successfully!
🎉 Migration Step X completed successfully!
```

---

## ⏱️ **Total Time**: ~25 minutes

All scripts are safe to re-run (they use upsert logic where possible).

**Exception**: Step 4 will create duplicates if re-run. To re-run Step 4:
```sql
DELETE FROM activity_responses WHERE knack_id IS NOT NULL;
```

---

**Ready to go!** 🎯


