# 🔄 Multi-Cycle Student Experience - How It Works

## 🎯 The Problem You Identified

You asked: **"What happens with Cycle 2 and Cycle 3 users?"**

This is a **critical question** - and you caught a bug I initially had! Here's the complete explanation:

---

## 📊 Student Journey Through Cycles

### Scenario: **Sarah's 2-Year VESPA Journey**

#### **CYCLE 1 - September 2024 (Year 12)**

**Sarah's Scores** (First time taking questionnaire):
- Vision: 3 (low)
- Effort: 4 (low)
- Systems: 6 (medium)
- Practice: 5 (medium)
- Attitude: 7 (good)

**What Happens:**
1. Completes questionnaire → Scores saved to Supabase
2. Opens Activities page → **No Cycle 1 activities in database yet**
3. System checks:
   - ✅ Has VESPA scores
   - ✅ Has no Cycle 1 activities (`myActivities.length === 0`)
   - ✅ localStorage: `'vespa-welcome-modal-seen-cycle-1'` = null
4. **WELCOME MODAL SHOWS** 🎉
5. Sarah clicks "Continue with These"
6. System prescribes 8-10 activities based on low Vision/Effort scores
7. localStorage: `'vespa-welcome-modal-seen-cycle-1'` = `'true'`

**Sarah's Cycle 1 Activities**:
- Prescribed: 10 activities (low-difficulty for Vision/Effort)
- Completes: 8 activities
- Points earned: 80 points
- Database: `activity_responses` with `cycle_number = 1`

**Sarah Returns Later in Year 12:**
- Opens Activities page
- System checks:
  - ✅ Has Cycle 1 activities (8 completed, 2 in progress)
  - ✅ localStorage: `'vespa-welcome-modal-seen-cycle-1'` = `'true'`
- **WELCOME MODAL DOES NOT SHOW** ✅ (Correct! She already has activities)
- Just shows her dashboard with progress

---

#### **CYCLE 2 - January 2025 (Still Year 12)**

Sarah improves after 6 months of working on activities!

**Sarah's NEW Scores** (Cycle 2 questionnaire):
- Vision: 7 ⬆️ (+4 improvement!)
- Effort: 8 ⬆️ (+4 improvement!)
- Systems: 7 ⬆️ (+1)
- Practice: 9 ⬆️ (+4)
- Attitude: 8 ⬆️ (+1)

**What Happens:**
1. Completes Cycle 2 questionnaire → **NEW scores** saved to Supabase
2. Opens Activities page
3. System detects: `current_cycle = 2` (from `vespa_students.current_cycle`)
4. System queries: `fetchMyActivities(cycle=2)` → **Empty! No Cycle 2 activities yet**
5. System checks:
   - ✅ Has VESPA scores (Cycle 2)
   - ✅ Has no Cycle 2 activities (`myActivities.length === 0`)
   - ✅ localStorage: `'vespa-welcome-modal-seen-cycle-2'` = null (key doesn't exist!)
   - ❌ localStorage: `'vespa-welcome-modal-seen-cycle-1'` = `'true'` (but we check cycle-2 key!)
6. **WELCOME MODAL SHOWS AGAIN** 🎉 (For Cycle 2!)
7. Modal shows **NEW recommended activities** based on improved scores
8. Now recommends **advanced** activities for Vision/Effort (she's improved!)
9. Sarah clicks "Continue with These" or "Choose Your Own"
10. localStorage: `'vespa-welcome-modal-seen-cycle-2'` = `'true'`

**Sarah's Cycle 2 Activities**:
- Prescribed: 8-10 NEW activities (harder ones - she's improved!)
- Old Cycle 1 activities: Still in database (cycle_number=1), not shown
- Database: New `activity_responses` with `cycle_number = 2`

---

#### **CYCLE 3 - September 2025 (Year 13)**

**Sarah's NEW Scores** (Cycle 3 questionnaire):
- Vision: 9 ⬆️
- Effort: 9 ⬆️
- Systems: 8 ⬆️
- Practice: 10 ⬆️
- Attitude: 9 ⬆️

**What Happens:**
1. Same flow as Cycle 2!
2. System detects: `current_cycle = 3`
3. Queries: `myActivities(cycle=3)` → Empty
4. localStorage: `'vespa-welcome-modal-seen-cycle-3'` = null
5. **WELCOME MODAL SHOWS AGAIN** 🎉 (Third time!)
6. Prescribes **expert-level** activities (she's now excellent!)
7. localStorage: `'vespa-welcome-modal-seen-cycle-3'` = `'true'`

---

## 🔑 Key Points - How It ALL Works

### ✅ **Cycle Isolation**
- Each cycle is **completely separate**
- Activities are stored with `cycle_number` field
- Queries filter: `WHERE cycle_number = ?`
- Student's Cycle 1 activities don't interfere with Cycle 2

### ✅ **Fresh Start Each Cycle**
- New questionnaire → New scores → New recommendations
- Welcome modal shows **once per cycle**
- localStorage keys: `cycle-1`, `cycle-2`, `cycle-3` (separate!)

### ✅ **Progress Preservation**
- Old cycle activities remain in database
- Staff can see historical progression
- Reports can compare Cycle 1 vs Cycle 2 scores
- But student only sees **current cycle** activities

---

## 📝 Database Structure (Multi-Cycle)

### Example: Sarah in Supabase

**vespa_scores table** (historical record):
```
student_email        | cycle | vision | effort | completion_date | academic_year
---------------------|-------|--------|--------|-----------------|---------------
sarah@school.com     | 1     | 3      | 4      | 2024-09-15      | 2024/2025
sarah@school.com     | 2     | 7      | 8      | 2025-01-20      | 2024/2025
sarah@school.com     | 3     | 9      | 9      | 2025-09-15      | 2025/2026
```

**activity_responses table** (all cycles preserved):
```
student_email    | activity_id | cycle_number | status     | completed_at
-----------------|-------------|--------------|------------|-------------
sarah@school.com | abc-123     | 1            | completed  | 2024-10-01
sarah@school.com | def-456     | 1            | completed  | 2024-10-15
sarah@school.com | ghi-789     | 2            | completed  | 2025-02-01
sarah@school.com | jkl-012     | 2            | in_progress| NULL
sarah@school.com | mno-345     | 3            | assigned   | NULL
```

**vespa_students table** (current state cache):
```
email            | current_cycle | latest_vespa_scores          | total_points | total_activities_completed
-----------------|---------------|------------------------------|--------------|----------------------------
sarah@school.com | 3             | {cycle:3, vision:9, ...}    | 380          | 24
```

**When Sarah opens Activities page:**
- System reads: `current_cycle = 3`
- Queries: `WHERE cycle_number = 3` → Shows only Cycle 3 activities
- Old Cycle 1 & 2 activities hidden from student (but preserved for staff/reports)

---

## 🎬 Complete User Flows

### **Flow 1: Brand New Student (Cycle 1, First Visit)**
```
1. Completes Cycle 1 questionnaire
2. Opens Activities page
3. myActivities(cycle=1) → 0 results
4. localStorage['cycle-1'] → null
5. → WELCOME MODAL SHOWS ✅
6. Clicks "Continue"
7. → 10 activities assigned (cycle_number=1)
8. localStorage['cycle-1'] = 'true'
```

### **Flow 2: Returning Student (Cycle 1, Second Visit)**
```
1. Opens Activities page
2. myActivities(cycle=1) → 10 results (has activities)
3. localStorage['cycle-1'] → 'true'
4. → DASHBOARD SHOWS ✅ (No modal - already has activities)
```

### **Flow 3: Cycle 2 Student (First Time on Cycle 2)**
```
1. Completes Cycle 2 questionnaire (new scores!)
2. Opens Activities page
3. System detects: current_cycle = 2
4. myActivities(cycle=2) → 0 results (no Cycle 2 activities yet)
5. localStorage['cycle-2'] → null (different key!)
6. localStorage['cycle-1'] → 'true' (ignored - we check cycle-2!)
7. → WELCOME MODAL SHOWS ✅ (Fresh start for Cycle 2!)
8. Prescribes NEW activities based on improved scores
9. localStorage['cycle-2'] = 'true'
```

### **Flow 4: Cycle 2 Student (Second Visit)**
```
1. Opens Activities page
2. current_cycle = 2
3. myActivities(cycle=2) → 8 results (has Cycle 2 activities)
4. localStorage['cycle-2'] → 'true'
5. → DASHBOARD SHOWS ✅ (No modal - already has Cycle 2 activities)
```

---

## 🐛 The Bug I Fixed (Thanks to Your Question!)

### Before Your Question:
```javascript
// ❌ WRONG - Not cycle-aware
localStorage.setItem('vespa-welcome-modal-seen', 'true');
```
**Problem**: Cycle 1 sets `'true'` → Cycle 2 can't see modal!

### After Your Question:
```javascript
// ✅ CORRECT - Cycle-aware
localStorage.setItem(`vespa-welcome-modal-seen-cycle-${currentCycle}`, 'true');
```
**Solution**: Each cycle has separate localStorage key!

---

## 🧪 Testing Multi-Cycle Experience

### Test Cycle 1 Modal:
```javascript
// Clear Cycle 1 localStorage
localStorage.removeItem('vespa-welcome-modal-seen-cycle-1');
location.reload();
```

### Test Cycle 2 Modal (Simulate cycle transition):
```javascript
// Simulate Cash on Cycle 2 (he should see modal if no Cycle 2 activities)
// First clear his Cycle 2 localStorage
localStorage.removeItem('vespa-welcome-modal-seen-cycle-2');
// His Cycle 1 localStorage can stay (it won't interfere!)
location.reload();
```

### Check What's in localStorage:
```javascript
// See all keys
console.log({
  cycle1: localStorage.getItem('vespa-welcome-modal-seen-cycle-1'),
  cycle2: localStorage.getItem('vespa-welcome-modal-seen-cycle-2'),
  cycle3: localStorage.getItem('vespa-welcome-modal-seen-cycle-3')
});
```

---

## 🎯 FINAL ANSWER TO YOUR QUESTIONS

### Q1: **Different experience for Cycle 1 vs Cycle 2 users?**
**A**: YES! Each cycle is a fresh start:
- Different scores → Different recommendations
- Welcome modal shows **once per cycle**
- Activities are cycle-isolated
- But UI/flow is identical

### Q2: **What happens with Cycle 2 and 3 users?**
**A**: They get the **SAME prescription flow** each cycle:
- Cycle 2: New questionnaire → New scores → Welcome modal → New activities
- Cycle 3: New questionnaire → New scores → Welcome modal → New activities
- Old cycle activities preserved but hidden from student view

### Q3: **Do activities propagate to Supabase?**
**A**: YES, 100% confident:
- Creates records in `activity_responses` (with correct cycle_number)
- Creates records in `student_activities`
- Logs to `activity_history`
- Staff sees them immediately via RPC
- Uses upsert to handle edge cases

---

## 🚀 Why This Design is Correct

1. **Students get fresh start each cycle** (motivating!)
2. **Old work is preserved** (for staff review & reports)
3. **No confusion between cycles** (clean separation)
4. **Prescription stays relevant** (based on NEW scores)
5. **LocalStorage won't block new cycles** (cycle-aware keys)

---

## 🔧 CRITICAL FIX DEPLOYED

I've just pushed the **cycle-aware localStorage fix**. The CDN will update in 2-3 minutes. This ensures:

✅ Cycle 1 students see modal once  
✅ Cycle 2 students see modal again (with new recommendations)  
✅ Cycle 3 students see modal again  
✅ No interference between cycles  

**This was a critical catch - thank you for asking!** Without this fix, Cycle 2 students would have been stuck. 🙏

---

Ready to test now? The system is **fully cycle-aware**!

