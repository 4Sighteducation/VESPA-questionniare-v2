# 🚀 Migration Quick Start Guide

## What We've Accomplished Today

✅ **Staff Dashboard** - WORKING and loading 29 students!  
✅ **RPC Functions** - Bypassing RLS properly  
✅ **Authentication** - Getting school context from API  
✅ **Build System** - Fixed and deploying to CDN  
✅ **Migration Scripts** - Ready to populate activity data  

## 🎯 Final Steps to Complete System

### Step 1: Run Activity Migration (15-20 min)

This will populate **all** student activity completions from Knack:

```bash
cd "C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\VESPAQuestionnaireV2\vespa-activities-v3\scripts"

npm install

# Get service key from Supabase dashboard → Settings → API → service_role key
$env:SUPABASE_SERVICE_KEY="your-service-key-here"

node migrate-activities-complete.js
```

**What it does:**
- Migrates 1,095 Object_126 records (current activity progress)
- Merges with Object_46 (student responses)
- Gets cycles from Object_10 (VESPA Results)
- Determines prescribed vs student_choice using threshold logic
- Handles ALL schools including VESPA ACADEMY

**Expected result:**
```
✅ Successfully migrated: 1,095 records
✅ VESPA ACADEMY responses: 29+ (tut7's students)
```

### Step 2: Populate Activity Thresholds (5 min)

This adds score thresholds to activities for prescription logic:

```bash
node populate-activity-thresholds.js
```

**What it does:**
- Reads `structured_activities_with_thresholds.json`
- Updates each activity's `score_threshold_min` and `score_threshold_max`
- Enables pure-Supabase prescription calculation

### Step 3: Update RPC Functions (2 min)

Already created! Just need to run in Supabase SQL Editor:

**File**: `vespa-upload-api/vespa-upload-api/SUPABASE_RPC_FUNCTIONS_FOR_DASHBOARDS.sql`

Run lines 16-72 (the `get_connected_students_for_staff` function with activity counts)

### Step 4: Update Dashboard Code (Already Done!)

Version **1k** already uses RPC functions. Just need to rebuild with activity count display:

```bash
cd "C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\VESPAQuestionnaireV2\vespa-activities-v3\staff"

# Update to version 1L in vite.config.js
npm run build
git add -A
git commit -m "Version 1L - With populated activity data"
git push
```

Then update KnackAppLoader to use `1L`.

## 🎉 After Migration

Your staff dashboard will show:
- ✅ **29 students** for tut7@vespa.academy
- ✅ **Activity counts** (completed vs total)
- ✅ **Progress circles** with real data
- ✅ **Click VIEW** to see student's completed activities
- ✅ **Gamification** (points, achievements) - ready to implement

## 📊 Current State

```
Activities Table:
  ✅ 500+ activities migrated
  ⚠️  Thresholds = NULL (run populate script)

Activity_Responses Table:
  ✅ 6,079 records (other schools)
  ❌ 0 VESPA ACADEMY records (run migration!)

Students/Staff:
  ✅ All migrated via Account Manager
  ✅ Connections working
  ✅ RLS policies in place
```

## 🔧 If Something Goes Wrong

### Migration fails midway:
- **Safe to re-run** - uses UPSERT
- Check error messages
- Fix specific issues
- Run again

### No data for VESPA ACADEMY after migration:
- Check Object_126 in Knack - do records exist?
- Check student emails match (field_91 in Object_6)
- Verify students exist in Supabase vespa_students table

### Dashboard still shows 0/0:
- Wait for jsDelivr CDN cache (2-3 minutes)
- Hard refresh browser (Ctrl+Shift+R)
- Check console for RPC errors
- Verify RPC function with activity counts is deployed

---

**You're SO close!** Just run the migration and the whole system comes alive! 🎉

