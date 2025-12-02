# 🔄 Cycle Filter Update - v1m (Student) + v3d (Staff)

**Date**: December 2, 2025  
**Student**: v1m (299KB)  
**Staff**: v3d (328KB)  
**Status**: ✅ Deployed to GitHub, syncing to CDN

---

## 🎯 **PROBLEM SOLVED**

### Before:
| User | View | Issue |
|------|------|-------|
| **Student** (Alena) | Cycle 3 only → 0 activities | ✅ Correct |
| **Staff** viewing Alena | ALL cycles → 57 activities | ❌ Confusing! |

**Result**: Looks like a bug - numbers don't match!

### After:
| User | View | Solution |
|------|------|----------|
| **Student** | Cycle 3 only → 0 activities | ✅ Same |
| **Staff** (default) | **Current Cycle Only (3)** → 0 activities | ✅ **MATCHES!** |
| **Staff** (dropdown) | Can choose: All / Cycle 1 / 2 / 3 | ✅ Flexible! |

---

## ✨ **STAFF DASHBOARD NEW FEATURE**

### Cycle Filter Dropdown
**Location**: StudentWorkspace header (next to search box)

**Options**:
```
[v] Current Cycle Only (3)  ← Default (matches student view!)
[ ] All Cycles              ← See all 57 activities
[ ] Cycle 1                 ← Just Cycle 1
[ ] Cycle 2                 ← Just Cycle 2
[ ] Cycle 3                 ← Just Cycle 3
```

**Behavior**:
- **Defaults to "Current Cycle"** → Shows what student sees
- Filters all activities by `cycle_number`
- Updates scorecard stats (completed/in-progress/total)
- Updates activity counts in category headers
- Persists during session (not saved to database)

---

## 🔧 **TECHNICAL CHANGES**

### Student (v1m):
- No changes (already cycle-aware)
- Still queries: `WHERE cycle_number = current_cycle`

### Staff (v3d):
```javascript
// NEW: Cycle filter ref
const selectedCycleFilter = ref('current'); // Default to current!

// NEW: Computed - filtered activities
const filteredActivitiesBySelectedCycle = computed(() => {
  if (selectedCycleFilter.value === 'all') {
    return allActivities; // Show all cycles
  }
  
  const targetCycle = selectedCycleFilter.value === 'current' 
    ? props.student.current_cycle 
    : parseInt(selectedCycleFilter.value);
  
  return allActivities.filter(a => a.cycle_number === targetCycle);
});

// UPDATED: Scorecard now uses filtered activities
<StudentScorecard :activities="filteredActivitiesBySelectedCycle" />
```

---

## 📋 **DEPLOYMENT CHECKLIST**

### Step 1: Run SQL (If Not Done Yet)
```sql
-- From: ADD_WELCOME_MODAL_TRACKING_FIELDS.sql
-- AND: CLEAR_ALENA_ACTIVITIES_COMPLETELY.sql

-- 1. Add tracking fields
ALTER TABLE vespa_students 
ADD COLUMN IF NOT EXISTS has_seen_welcome_cycle_1 BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS has_seen_welcome_cycle_2 BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS has_seen_welcome_cycle_3 BOOLEAN DEFAULT false;

-- 2. Fix cycle mismatches
UPDATE vespa_students
SET current_cycle = (latest_vespa_scores->>'cycle')::int
WHERE latest_vespa_scores->>'cycle' IS NOT NULL
  AND (latest_vespa_scores->>'cycle')::int != current_cycle;

-- 3. Clear Alena's activities (BOTH tables!)
UPDATE activity_responses
SET status = 'removed'
WHERE student_email = 'aramsey@vespa.academy'
  AND status != 'removed';

UPDATE student_activities
SET status = 'removed'
WHERE student_email = 'aramsey@vespa.academy'
  AND status != 'removed';
```

### Step 2: Wait 2-3 Minutes
CDN syncing from GitHub:
- `student-activities1m.js` ✅
- `activity-dashboard-3d.js` ✅

### Step 3: Update KnackAppLoader
**File**: `Homepage/KnackAppLoader(copy).js`

**Lines 1535-1536** (Student):
```javascript
scriptUrl: '...student-activities1m.js'  // Was 1k
cssUrl: '...student-activities1m.css'
```

**Lines 1556-1557** (Staff):
```javascript
scriptUrl: '...activity-dashboard-3d.js'  // Was 3c
cssUrl: '...activity-dashboard-3d.css'
```

Copy entire file → Paste into Knack → Save

### Step 4: Test!

---

## 🧪 **WHAT TO TEST**

### Test 1: Student View (Alena - Cycle 3)
```
1. Log in as aramsey@vespa.academy
2. Go to Activities page
3. ✅ Should see welcome modal (0 Cycle 3 activities)
4. ✅ Shows Cycle 3 scores (Vision:9, Effort:2, etc.)
5. Click "Continue" or "Choose Your Own"
6. ✅ Activities assigned to Cycle 3
7. Refresh → Motivational popup shows
```

### Test 2: Staff View (After Alena Assigns Activities)
```
1. Open staff dashboard
2. View Alena's workspace
3. ✅ Cycle filter shows "Current Cycle Only (3)" ← Default!
4. ✅ Shows SAME activities as student (e.g., 6 activities)
5. ✅ Scorecard matches: "6 total, 0 completed"
6. Change dropdown to "All Cycles"
7. ✅ NOW shows all 70 activities (Cycle 1 + 3)
8. ✅ Scorecard updates: "70 total, 63 completed"
```

### Test 3: Consistency Check
```
BEFORE Filter:
- Student sees: 6 activities
- Staff sees: 70 activities ❌ MISMATCH!

AFTER Filter (Current Cycle Only):
- Student sees: 6 activities
- Staff sees: 6 activities ✅ MATCH!

Switch to "All Cycles":
- Staff sees: 70 activities ✅ With context!
```

---

## 📊 **EXAMPLE: Alena's View**

### Student Dashboard:
```
Current Cycle: 3
Activities shown: 6 (Cycle 3 only)
```

### Staff Dashboard (Default):
```
Dropdown: [Current Cycle Only (3)]
Activities shown: 6 (Cycle 3 only)
Scorecard: 6 total, 0 completed ← MATCHES STUDENT!
```

### Staff Dashboard (All Cycles):
```
Dropdown: [All Cycles]
Activities shown: 70
- Cycle 1: 63 (all completed)
- Cycle 3: 7 (in progress)
Scorecard: 70 total, 63 completed ← HISTORICAL VIEW
```

---

## 🎉 **BENEFITS**

1. **Default View Matches Student** ✅
   - No more confusion
   - Staff sees exactly what student sees
   
2. **Historical View Available** ✅
   - Can switch to "All Cycles" anytime
   - See student progression across years
   
3. **Specific Cycle Selection** ✅
   - Review Cycle 1 work
   - Compare Cycle 1 vs Cycle 2
   
4. **Clear Communication** ✅
   - Dropdown shows "(3)" = current cycle
   - No ambiguity about what you're seeing

---

## 🚀 **READY TO DEPLOY**

**CDN URLs**:
```
Student v1m:
https://cdn.jsdelivr.net/gh/4Sighteducation/VESPA-questionniare-v2@main/vespa-activities-v3/student/dist/student-activities1m.js

Staff v3d:
https://cdn.jsdelivr.net/gh/4Sighteducation/VESPA-questionniare-v2@main/vespa-activities-v3/staff/dist/activity-dashboard-3d.js
```

**KnackAppLoader Changes**:
- Line 1535-1536: v1m (student)
- Line 1556-1557: v3d (staff)

---

**Copy KnackAppLoader, wait for CDN, then test! This solves the cycle mismatch confusion!** 🎯

