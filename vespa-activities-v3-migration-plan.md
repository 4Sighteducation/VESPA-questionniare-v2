# VESPA Activities V3 - Supabase Migration Implementation Plan

## ✅ Supabase Tables Created Successfully

All tables created with indexes and constraints:
- `activities` (75 records)
- `activity_questions` (1,573 records)
- `students` (auto-populated on first access)
- `activity_responses` (6,060 historical records to migrate)
- `student_activities` (student dashboard)
- `student_achievements` (gamification)
- `staff_student_connections` (many-to-many relationships)
- `notifications` (real-time system)
- `activity_history` (audit trail)
- `achievement_definitions` (rules engine)

---

## 📦 Migration Sequence

### **Step 1: Migrate Activities (75 records)**
Source: `vespa-activities-v2/shared/utils/structured_activities_with_thresholds.json`
Script: `migration_scripts/01_migrate_activities.py`
Duration: ~2 minutes

### **Step 2: Migrate Questions (1,573 records)**
Source: `VESPAQuestionnaireV2/activityquestion.csv`
Script: `migration_scripts/02_migrate_questions.py`
Duration: ~5 minutes
Note: Links questions to activities via activity name matching

### **Step 3: Migrate Problem Mappings**
Source: `vespa-activities-v2/shared/vespa-problem-activity-mappings1a.json`
Script: `migration_scripts/03_update_problem_mappings.py`
Duration: ~1 minute
Updates: `activities.problem_mappings` array field

### **Step 4: Migrate Historical Responses (6,060 records)**
Source: Knack Object_46 via API
Script: `migration_scripts/04_migrate_historical_responses.py`
Duration: ~15 minutes
Filters: 
- `field_1870 >= '2025-01-01'`
- `field_1301 IS NOT NULL` (student email exists)

### **Step 5: Seed Achievement Definitions**
Script: `migration_scripts/05_seed_achievements.py`
Duration: ~1 minute
Creates: 20+ achievement types with criteria

---

## 🏗️ Vue App Structure

### **Repository Organization**
```
vespa-activities-v3/
├── student/                              # Student Activities App
│   ├── src/
│   │   ├── components/
│   │   ├── composables/
│   │   ├── services/
│   │   ├── utils/
│   │   ├── App.vue
│   │   ├── main.js
│   │   └── style.css
│   ├── dist/                             # Build output
│   ├── package.json
│   └── vite.config.js
│
├── staff/                                # Staff Activities Monitor App
│   ├── src/
│   │   ├── components/
│   │   ├── composables/
│   │   ├── services/
│   │   ├── App.vue
│   │   ├── main.js
│   │   └── style.css
│   ├── dist/
│   ├── package.json
│   └── vite.config.js
│
├── shared/                               # Shared utilities
│   ├── supabaseClient.js
│   ├── types.js
│   └── constants.js
│
├── migration_scripts/                    # Python migration scripts
│   ├── requirements.txt
│   ├── 01_migrate_activities.py
│   ├── 02_migrate_questions.py
│   ├── 03_update_problem_mappings.py
│   ├── 04_migrate_historical_responses.py
│   └── 05_seed_achievements.py
│
└── README.md
```

---

## 🔐 Row Level Security (RLS) Policies

### **Students Table**
```sql
-- Students can read their own record
CREATE POLICY "Students can read own record"
ON students FOR SELECT
TO authenticated
USING (email = auth.jwt() ->> 'email');

-- Service role can do everything
CREATE POLICY "Service role full access"
ON students FOR ALL
TO service_role
USING (true);
```

### **Activity Responses Table**
```sql
-- Students can read/write their own responses
CREATE POLICY "Students can manage own responses"
ON activity_responses FOR ALL
TO authenticated
USING (student_email = auth.jwt() ->> 'email');

-- Staff can read responses of connected students
CREATE POLICY "Staff can read connected student responses"
ON activity_responses FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM staff_student_connections
    WHERE staff_email = auth.jwt() ->> 'email'
    AND student_email = activity_responses.student_email
  )
);

-- Staff can update (add feedback) to connected student responses
CREATE POLICY "Staff can add feedback to connected students"
ON activity_responses FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM staff_student_connections
    WHERE staff_email = auth.jwt() ->> 'email'
    AND student_email = activity_responses.student_email
  )
);
```

### **Notifications Table**
```sql
-- Users can read their own notifications
CREATE POLICY "Users can read own notifications"
ON notifications FOR SELECT
TO authenticated
USING (recipient_email = auth.jwt() ->> 'email');

-- Users can update (mark read) their own notifications
CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
TO authenticated
USING (recipient_email = auth.jwt() ->> 'email');
```

---

## 🚀 Deployment Workflow

### **Student App Deployment**
```bash
# Build with version increment
cd student
npm run build  # Outputs: dist/student-activities1a.js

# Push to GitHub
git add .
git commit -m "Student Activities V3 - Version 1a"
git push origin main

# Update KnackAppLoader
# Change: student-activities1a.js → student-activities1b.js (for next version)

# Upload KnackAppLoader to Knack Builder
```

### **Staff App Deployment**
```bash
# Build with version increment
cd staff
npm run build  # Outputs: dist/staff-overview1a.js

# Push to GitHub
git add .
git commit -m "Staff Activities Monitor V3 - Version 1a"
git push origin main

# Update KnackAppLoader
```

---

## 🎯 Immediate Next Steps

1. ✅ Run migration scripts (Python)
2. ✅ Create Vue 3 project scaffolds (student + staff)
3. ✅ Build core components
4. ✅ Connect to Supabase
5. ✅ Test locally with dev server
6. ✅ Build and deploy to GitHub
7. ✅ Create Knack scenes (scene_1288, scene_1290)
8. ✅ Update KnackAppLoader with new app configs
9. ✅ Test in Knack production

---

## 📊 Success Metrics

**Must Work:**
- ✅ Student sees recommended activities based on VESPA scores
- ✅ Student can select activities by problem
- ✅ Student can complete activities with auto-save
- ✅ Progress tracked in Supabase
- ✅ Staff sees ALL connected students
- ✅ Staff can assign/remove activities
- ✅ Staff can give feedback
- ✅ Notifications work in real-time
- ✅ Achievements auto-award on milestones

**Performance Targets:**
- Initial load < 2 seconds
- Activity modal opens instantly
- Auto-save doesn't block UI
- Staff dashboard renders 100+ students < 3 seconds

---

## 🔧 Environment Variables Needed

### **Student App (.env)**
```bash
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
VITE_API_URL=https://vespa-dashboard-9a1f84ee5341.herokuapp.com
VITE_KNACK_APP_ID=66e26296d863e5001c6f1e09
VITE_PROBLEM_MAPPINGS_URL=https://cdn.jsdelivr.net/gh/4Sighteducation/vespa-activities-v3@main/shared/vespa-problem-activity-mappings1a.json
```

### **Staff App (.env)**
```bash
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
VITE_API_URL=https://vespa-dashboard-9a1f84ee5341.herokuapp.com
VITE_KNACK_APP_ID=66e26296d863e5001c6f1e09
```

### **Migration Scripts (.env)**
```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key
KNACK_APP_ID=66e26296d863e5001c6f1e09
KNACK_API_KEY=0b19dcb0-9f43-11ef-8724-eb3bc75b770f
```

---

## 📝 Notes

- All apps wrapped in IIFE to prevent DOM conflicts ✅
- Version naming: 1a → 1b → 1c (CDN cache busting) ✅
- Scene-level rendering with `hideOriginalView: true` ✅
- VESPA color palette (#079baa, #7bd8d0, #62d1d2, etc.) ✅
- Mobile responsive from day 1 ✅

---

**Status**: Ready to proceed with implementation!
**Next Action**: Create migration scripts or Vue app scaffold?


