# VESPA Activities V3 - Complete Handover Document

**Project**: VESPA Activities Migration to Supabase  
**Status**: ✅ Database schema complete, ready for data migration  
**Date**: November 11, 2025  
**Context**: New architecture for activities system with eventual full Knack independence

---

## 📋 **Table of Contents**
1. [Project Overview](#project-overview)
2. [Architecture Rationale](#architecture-rationale)
3. [Database Schema](#database-schema)
4. [Knack Field Mappings](#knack-field-mappings)
5. [Current State](#current-state)
6. [Migration Phases](#migration-phases)
7. [File Structure](#file-structure)
8. [Next Steps](#next-steps)
9. [KnackAppLoader Configuration](#knackapploader-configuration)

---

## 🎯 **Project Overview**

### **Goal**
Migrate VESPA Activities system from Knack (Objects 44, 45, 46) to Supabase while:
- ✅ Maintaining backwards compatibility with questionnaire/reports
- ✅ Solving multi-year student data issues
- ✅ Building path to eventual Knack independence
- ✅ Creating real-time features (notifications, instant feedback)
- ✅ Improving gamification system

### **Current Knack Setup**
- **Scene 1258**: Old student activities (to be replaced)
- **Scene 1288** / `view_3262` / `#vespa-activities`: New student activities ✅
- **Scene 1290** / `view_3268` / `#activity-monitor`: New staff monitor ✅

### **Problem Being Solved**
The existing Knack-based activities system has critical issues:
1. Complex many-to-many relationships causing performance issues
2. Progress tracking bugs (duplicate records, date format errors)
3. Multi-year students create duplicate records (Year 12 → Year 13 = new Knack ID)
4. Legacy `students` table has data integrity issues (duplicate emails, duplicate knack_ids)
5. Can't add real-time features in Knack
6. Gamification limited by Knack constraints

---

## 🏗️ **Architecture Rationale**

### **Key Design Decision: Separate `vespa_students` Table**

#### **Why NOT Use Existing `students` Table?**

**Problem Discovered:**
```sql
-- Legacy students table structure
students:
  - Uses student_id (UUID) as foreign key
  - Has duplicate emails (multi-year students)
  - Has duplicate knack_ids (year rollovers)
  - Used by: vespa_scores, question_responses, staff_coaching_notes, student_comments, etc.

-- Foreign keys:
vespa_scores.student_id → students.id (UUID)
question_responses.student_id → students.id (UUID)
```

**Why This Causes Issues:**
1. **Can't enforce email uniqueness** without breaking questionnaire/reports
2. **Can't delete duplicate records** without orphaning VESPA scores
3. **Year rollover creates new records** instead of updating existing
4. **Data integrity cleanup is risky** - would break existing foreign keys

#### **Solution: New `vespa_students` Table**

**Benefits:**
- ✅ **Clean slate**: No legacy data issues
- ✅ **Email unique enforced**: One canonical record per student
- ✅ **Separate foreign keys**: Uses `student_email` (VARCHAR) instead of `student_id` (UUID)
- ✅ **Year rollover handling**: Updates single record, tracks history
- ✅ **Coexists peacefully**: Doesn't conflict with legacy system
- ✅ **Future auth ready**: Fields for Supabase auth migration
- ✅ **Eventual migration path**: Can become THE student registry for all systems

---

## 💾 **Database Schema**

### **Core Tables Created** ✅

#### **1. `activities` (75 records to import)**
Master activity library - replaces Knack Object_44

```sql
activities:
  id (UUID) - Primary key
  knack_id (VARCHAR) - Original Knack record ID
  name (VARCHAR) - Activity name (UNIQUE)
  slug (VARCHAR) - URL-friendly name
  vespa_category (VARCHAR) - Vision/Effort/Systems/Practice/Attitude
  level (VARCHAR) - "Level 2" or "Level 3"
  difficulty (INTEGER) - 0-10 scale
  time_minutes (INTEGER) - Expected duration
  
  -- Scoring thresholds (when to recommend)
  score_threshold_min (INTEGER) - Show if VESPA score > X
  score_threshold_max (INTEGER) - Show if VESPA score <= Y
  
  -- Content
  content (JSONB) - Structured sections {do, think, learn, reflect}
  do_section_html (TEXT) - Rich HTML from Knack field_1289
  think_section_html (TEXT) - Rich HTML from Knack field_1288
  learn_section_html (TEXT) - Rich HTML from Knack field_1293
  reflect_section_html (TEXT) - Rich HTML from Knack field_1313
  
  -- Problem mappings (for self-selection)
  problem_mappings (TEXT[]) - Array of problem IDs
  curriculum_tags (TEXT[]) - For filtering
  
  -- Display
  color (VARCHAR) - "Vespa Rose", "Vespa Sky Blue", etc.
  display_order (INTEGER) - Sort order
  is_active (BOOLEAN) - Active/inactive flag
```

#### **2. `activity_questions` (1,573 records to import)**
Dynamic questions per activity - replaces Knack Object_45

```sql
activity_questions:
  id (UUID) - Primary key
  activity_id (UUID) - FK to activities
  
  question_title (TEXT) - The question text
  text_above_question (TEXT) - HTML instructions/context
  question_type (VARCHAR) - Dropdown/Paragraph Text/Short Text/Date/Checkboxes
  dropdown_options (TEXT[]) - Options for dropdowns
  
  display_order (INTEGER) - Sort order
  is_active (BOOLEAN) - Active/inactive
  answer_required (BOOLEAN) - Validation flag
  show_in_final_questions (BOOLEAN) - Display in summary
```

#### **3. `vespa_students` (NEW - Canonical Registry)**
Clean student registry with multi-year support

```sql
vespa_students:
  id (UUID) - Primary key
  email (VARCHAR) - UNIQUE ✅ Primary identifier (never changes)
  
  -- Knack references (handles year rollover)
  current_knack_id (VARCHAR) - Latest Knack ID
  historical_knack_ids (TEXT[]) - All previous Knack IDs
  
  -- Future Supabase auth (Phase 2+)
  supabase_user_id (UUID) - References auth.users
  auth_provider (VARCHAR) - 'knack' or 'supabase'
  last_login_at (TIMESTAMP)
  login_count (INTEGER)
  
  -- Basic info
  first_name, last_name, full_name
  date_of_birth (DATE)
  
  -- School context
  school_id (UUID) - Future reference
  school_name (VARCHAR)
  trust_name (VARCHAR)
  current_year_group (VARCHAR) - Updates each year
  current_academic_year (VARCHAR) - "2025/2026"
  student_group (VARCHAR)
  
  -- Academic context
  current_level (VARCHAR) - "Level 2" or "Level 3"
  current_cycle (INTEGER) - 1, 2, or 3
  enrollment_date (DATE)
  expected_graduation_date (DATE)
  
  -- VESPA scores cache (for performance)
  latest_vespa_scores (JSONB) - Latest scores snapshot
  
  -- Gamification (cached totals)
  total_points (INTEGER)
  total_activities_completed (INTEGER)
  total_achievements (INTEGER)
  current_streak_days (INTEGER)
  longest_streak_days (INTEGER)
  
  -- Status
  status (VARCHAR) - active/graduated/withdrawn/suspended
  is_active (BOOLEAN)
  last_activity_at (TIMESTAMP)
  
  -- Year tracking
  years_in_system (INTEGER)
  previous_academic_years (TEXT[])
  
  -- Contact
  phone_number, parent_email, parent_phone
  
  -- Preferences
  preferences (JSONB) - User settings
  
  -- Sync
  last_synced_from_knack (TIMESTAMP)
  knack_user_attributes (JSONB) - Full Knack user object
```

#### **4. `activity_responses` (6,060 historical records to import)**
Student responses to activities - replaces Knack Object_46

```sql
activity_responses:
  id (UUID)
  knack_id (VARCHAR) - Original Object_46 record ID
  
  student_email (VARCHAR) - FK to vespa_students.email ✅
  activity_id (UUID) - FK to activities.id
  
  cycle_number (INTEGER)
  academic_year (VARCHAR)
  
  responses (JSONB) - All question answers
  responses_text (TEXT) - Concatenated for search
  
  status (VARCHAR) - in_progress/completed/abandoned
  started_at, completed_at (TIMESTAMP)
  time_spent_minutes (INTEGER)
  word_count (INTEGER)
  
  -- Staff feedback
  staff_feedback (TEXT)
  staff_feedback_by (VARCHAR) - Staff email
  staff_feedback_at (TIMESTAMP)
  feedback_read_by_student (BOOLEAN)
  feedback_read_at (TIMESTAMP)
  
  selected_via (VARCHAR) - staff_assigned/student_choice/recommended/auto
```

#### **5. `student_activities`**
Student's activity dashboard (prescribed/assigned)

```sql
student_activities:
  student_email (VARCHAR) - FK to vespa_students.email
  activity_id (UUID) - FK to activities.id
  
  assigned_at (TIMESTAMP)
  assigned_by (VARCHAR) - 'auto' or staff email
  assigned_reason (VARCHAR) - "low_vision_score", etc.
  
  status (VARCHAR) - assigned/started/completed/removed
  removed_at (TIMESTAMP)
  
  cycle_number (INTEGER)
```

#### **6. `student_achievements`**
Enhanced gamification system

```sql
student_achievements:
  student_email (VARCHAR) - FK to vespa_students.email
  
  achievement_type (VARCHAR) - milestone/streak/category_master/custom
  achievement_name (VARCHAR)
  achievement_description (TEXT)
  icon_emoji (VARCHAR)
  
  points_value (INTEGER)
  criteria_met (JSONB) - What triggered it
  
  date_earned (TIMESTAMP)
  issued_by_staff (VARCHAR) - NULL if auto-awarded
  is_pinned (BOOLEAN)
```

#### **7. `staff_student_connections`**
Many-to-many staff-student relationships

```sql
staff_student_connections:
  staff_email (VARCHAR)
  student_email (VARCHAR) - FK to vespa_students.email
  staff_role (VARCHAR) - tutor/staff_admin/head_of_year/subject_teacher
  
  synced_from_knack (BOOLEAN)
  last_synced_at (TIMESTAMP)
```

#### **8. `notifications`**
Real-time notification system

```sql
notifications:
  recipient_email (VARCHAR)
  recipient_type (VARCHAR) - student/staff
  
  notification_type (VARCHAR) - feedback_received/activity_assigned/achievement_earned/etc
  title (VARCHAR)
  message (TEXT)
  action_url (TEXT) - Deep link
  
  related_activity_id (UUID)
  related_response_id (UUID)
  related_achievement_id (UUID)
  
  is_read (BOOLEAN)
  read_at (TIMESTAMP)
  priority (VARCHAR) - urgent/high/normal/low
```

#### **9. `activity_history`**
Comprehensive audit log

```sql
activity_history:
  student_email (VARCHAR)
  activity_id (UUID)
  activity_name (VARCHAR) - Denormalized
  
  action (VARCHAR) - assigned/started/completed/removed
  triggered_by (VARCHAR) - student/staff/system
  triggered_by_email (VARCHAR)
  
  cycle_number (INTEGER)
  academic_year (VARCHAR)
  metadata (JSONB)
  
  timestamp (TIMESTAMP)
```

#### **10. `achievement_definitions`**
Gamification rules engine

```sql
achievement_definitions:
  achievement_type (VARCHAR UNIQUE)
  name (VARCHAR)
  description (TEXT)
  icon_emoji (VARCHAR)
  points_value (INTEGER)
  
  criteria (JSONB) - Rules for triggering
  /*
  Examples:
  {"type": "activities_completed", "count": 5}
  {"type": "streak", "days": 7}
  {"type": "category_master", "category": "Vision", "percentage": 80}
  */
  
  is_active (BOOLEAN)
  display_order (INTEGER)
```

---

## 🗺️ **Knack Field Mappings**

### **Object_44 (Activities) → activities table**

| Knack Field | Field ID | Type | Supabase Column | Notes |
|-------------|----------|------|-----------------|-------|
| Activity Name | field_1278 | Text | name | Unique identifier |
| DO Section | field_1289 | Rich Text | do_section_html | Rich HTML content |
| THINK Section | field_1288 | Rich Text | think_section_html | Videos/slides |
| LEARN Section | field_1293 | Rich Text | learn_section_html | Educational content |
| REFLECT Section | field_1313 | Rich Text | reflect_section_html | Final thoughts |
| VESPA Category | field_1285 | Connection | vespa_category | Vision/Effort/Systems/Practice/Attitude |
| Score More Than | field_1287 | Number | score_threshold_min | Show if score > X |
| Score Less/Equal | field_1294 | Number | score_threshold_max | Show if score <= Y |
| Level (Alt) | field_3568 | Text | level | "Level 2" or "Level 3" (preferred) |
| Level (Fallback) | field_1295 | Text | level | Fallback if field_3568 empty |
| Difficulty | field_1298 | Number | difficulty | 0-10 scale |
| Active | field_1299 | Yes/No | is_active | Active/inactive |
| Display Order | field_2072 | Number | display_order | Sort order |
| Record ID | id | Auto | knack_id | Original Knack ID |

### **Object_45 (Questions) → activity_questions table**

| Knack Field | Field ID | Type | Supabase Column | Notes |
|-------------|----------|------|-----------------|-------|
| Question Title | field_1279 | Text | question_title | The question text |
| Text Above Question | field_1310 | Rich Text | text_above_question | HTML instructions |
| Type | field_1290 | Multiple Choice | question_type | Dropdown/Paragraph/etc |
| Dropdown Options | field_1291 | Text | dropdown_options | CSV → Array |
| Order | field_1303 | Number | display_order | Sort order |
| Active | field_1292 | Multiple Choice | is_active | True/False |
| Answer Required | field_2341 | Yes/No | answer_required | Validation |
| Show in Final | field_1314 | Yes/No | show_in_final_questions | Display flag |
| Activity | field_1286 | Connection | activity_id | Link to activity |

### **Object_46 (Answers) → activity_responses table**

| Knack Field | Field ID | Type | Supabase Column | Notes |
|-------------|----------|------|-----------------|-------|
| Student | field_1301 | Connection | student_email | KEY: Email from connection |
| Activity | field_1302 | Connection | activity_id | Activity UUID |
| Activity Answers JSON | field_1300 | Paragraph | responses | JSON responses |
| Student Responses | field_2334 | Paragraph | responses_text | Text responses |
| Completion Date | field_1870 | Date/Time | completed_at | When finished |
| Staff Feedback | field_1734 | Paragraph | staff_feedback | Feedback text |
| Tutor | field_1872 | Connection | staff_feedback_by | Tutor email |
| Staff Admin | field_1873 | Connection | staff_feedback_by | Admin email |
| Year Group | field_2331 | Text | year_group | Context |
| Group | field_2332 | Text | student_group | Context |
| Record ID | id | Auto | knack_id | Original ID |

---

## 🔄 **How Year Rollover Works**

### **OLD System (Knack/Legacy students table):**
```
Year 12 (2024/2025):
  students: email="student@school.com", knack_id="abc123" (Record 1)
  
Year 13 (2025/2026):
  School deletes/re-imports → New Knack ID
  students: email="student@school.com", knack_id="def456" (Record 2)
  
Result: 2 duplicate records ❌
```

### **NEW System (vespa_students):**
```
Year 12 (2024/2025):
  vespa_students:
    email="student@school.com"
    current_knack_id="abc123"
    historical_knack_ids=["abc123"]
    current_year_group="Year 12"
  
Year 13 (2025/2026):
  Detect Knack ID changed → UPDATE existing record:
  vespa_students:
    email="student@school.com" (SAME RECORD)
    current_knack_id="def456" ← Updated
    historical_knack_ids=["abc123", "def456"] ← Appended
    current_year_group="Year 13" ← Updated
    years_in_system=2 ← Incremented
  
Result: 1 clean record with full history ✅
```

### **Auto-Update Function:**
```sql
-- Called when student logs in with different Knack ID
SELECT get_or_create_vespa_student(
  'student@school.com',
  Knack.getUserAttributes()  -- Includes new knack_id
);

-- Function automatically:
-- 1. Checks if email exists
-- 2. Compares current_knack_id
-- 3. If different, updates and appends to historical_knack_ids
-- 4. Returns existing record
```

---

## 📊 **Current State**

### **✅ Completed:**
1. Supabase schema designed and created
2. All 10 tables created with indexes
3. Helper functions for year rollovers
4. RLS policies configured
5. Migration scripts written (Python)
6. Vue 3 app structure created (skeleton)
7. Shared composables/services scaffolded

### **📂 Ready for Migration:**
- 75 activities from `structured_activities_with_thresholds.json`
- 1,573 questions from `activityquestion.csv`
- 6,060 historical responses from Knack Object_46 (since Jan 2025)

### **🚫 Not Started:**
- Running migration scripts (data import)
- Building Vue components
- Backend API endpoints
- Frontend-backend integration
- Testing in Knack

---

## 🎯 **Migration Phases**

### **Phase 1: Activities Launch (Current - 0-2 months)**
**Status**: In progress ✅ Schema complete

**Auth**: Knack only
```javascript
const userEmail = Knack.getUserAttributes().email;
// Backend creates/syncs vespa_students record automatically
```

**Data Flow**:
```
Student logs in (Knack) 
    ↓
Vue app gets email from Knack.getUserAttributes()
    ↓
Backend calls get_or_create_vespa_student(email, knack_attrs)
    ↓
Creates/updates record in vespa_students
    ↓
All activities queries use student_email
    ↓
Activities, progress, achievements all in Supabase
```

**Coexistence**:
- Legacy `students` → Questionnaire/Reports (unchanged)
- New `vespa_students` → Activities (new system)
- Both use same Knack auth
- Separate foreign key patterns (UUID vs email)

### **Phase 2: Dual Auth (3-6 months)**
**New users**: Created in vespa_students with Supabase auth  
**Existing users**: Knack auth, auto-sync to vespa_students  
**Vue apps**: Check Supabase auth first, fallback to Knack  

### **Phase 3: Questionnaire/Reports Migration (6-12 months)**
- Migrate vespa_scores: `student_id` (UUID) → `student_email` (VARCHAR)
- Migrate question_responses: `student_id` → `student_email`
- Use vespa_students as source of truth
- Legacy `students` table becomes archive

### **Phase 4: Complete Independence (12+ months)**
- All systems use vespa_students
- Knack auth disabled
- 100% Supabase platform ✅

---

## 📁 **File Structure**

```
VESPAQuestionnaireV2/
├── vespa-activities-v3/
│   ├── ARCHITECTURE_VISION.md          # Overall migration roadmap
│   ├── HANDOVER_COMPLETE.md            # This file
│   │
│   ├── 00_CLEANUP_ALL.sql              # Drop all tables (run first if resetting)
│   ├── FUTURE_READY_SCHEMA.sql         # ✅ MAIN SCHEMA (run this!)
│   ├── FUTURE_VESPA_STAFF_SCHEMA.sql   # Future vespa_staff table (Phase 2)
│   │
│   ├── KNACKAPPLOADER_CONFIG.js        # Config for KnackAppLoader
│   │
│   ├── migration_scripts/
│   │   ├── requirements.txt            # Python dependencies
│   │   ├── .env.example                # Environment variables template
│   │   ├── README_MIGRATION.md         # Migration guide
│   │   ├── 01_migrate_activities.py    # Import 75 activities
│   │   ├── 02_migrate_questions.py     # Import 1,573 questions
│   │   ├── 03_update_problem_mappings.py  # Link problems
│   │   ├── 04_migrate_historical_responses.py  # Import 6,060 responses
│   │   └── 05_seed_achievements.py     # Create 23 achievement types
│   │
│   ├── student/                        # Vue 3 Student App
│   │   ├── src/
│   │   │   ├── components/            # Vue components
│   │   │   ├── composables/           # useActivities, useVESPAScores, etc
│   │   │   ├── services/              # API service layer
│   │   │   ├── utils/                 # Helper functions
│   │   │   ├── App.vue                # Main app (IIFE wrapped)
│   │   │   ├── main.js                # Entry point
│   │   │   └── style.css              # Global styles
│   │   ├── dist/                      # Build output (CDN)
│   │   ├── package.json
│   │   ├── vite.config.js             # Build config
│   │   └── index.html
│   │
│   ├── staff/                         # Vue 3 Staff Monitor App
│   │   └── (similar structure)
│   │
│   └── shared/                        # Shared utilities
│       ├── supabaseClient.js          # Supabase connection
│       ├── constants.js               # Shared constants
│       └── types.js                   # TypeScript types (future)
│
└── vespa-activities-v2/               # OLD SYSTEM (reference only)
    ├── student/VESPAactivitiesStudent4q.js  # 7,058 lines (to be replaced)
    ├── staff/VESPAactivitiesStaff8b.js      # 6,455 lines (to be replaced)
    └── shared/utils/
        ├── structured_activities_with_thresholds.json  # Source data
        ├── activity_json_final1a.json
        └── vespa-problem-activity-mappings1a.json
```

---

## 🔌 **KnackAppLoader Configuration**

### **Add to `KnackAppLoader(copy).js` APPS object:**

```javascript
'studentActivitiesV3': {
    scenes: ['scene_1288'],
    views: ['view_3262'],
    scriptUrl: 'https://cdn.jsdelivr.net/gh/4Sighteducation/vespa-activities-v3@main/student/dist/student-activities1a.js',
    cssUrl: 'https://cdn.jsdelivr.net/gh/4Sighteducation/vespa-activities-v3@main/student/dist/student-activities1a.css',
    configBuilder: (baseConfig, sceneKey, viewKey) => ({
        ...baseConfig,
        appType: 'studentActivitiesV3',
        sceneKey: sceneKey,
        viewKey: viewKey,
        debugMode: true,  // Set false for production
        elementSelector: '#view_3262',
        renderMode: 'replace',
        hideOriginalView: true,
        apiUrl: 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com'
    }),
    configGlobalVar: 'STUDENT_ACTIVITIES_V3_CONFIG',
    initializerFunctionName: 'initializeStudentActivitiesV3'
},

'staffActivitiesMonitorV3': {
    scenes: ['scene_1290'],
    views: ['view_3268'],
    scriptUrl: 'https://cdn.jsdelivr.net/gh/4Sighteducation/vespa-activities-v3@main/staff/dist/staff-monitor1a.js',
    cssUrl: 'https://cdn.jsdelivr.net/gh/4Sighteducation/vespa-activities-v3@main/staff/dist/staff-monitor1a.css',
    configBuilder: (baseConfig, sceneKey, viewKey) => ({
        ...baseConfig,
        appType: 'staffActivitiesMonitorV3',
        sceneKey: sceneKey,
        viewKey: viewKey,
        debugMode: true,
        elementSelector: '#view_3268',
        renderMode: 'replace',
        hideOriginalView: true,
        apiUrl: 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com'
    }),
    configGlobalVar: 'STAFF_ACTIVITIES_MONITOR_V3_CONFIG',
    initializerFunctionName: 'initializeStaffActivitiesMonitorV3'
}
```

### **How It Loads:**
1. Knack renders scene_1288 or scene_1290
2. KnackAppLoader detects scene/view match
3. Loads Vue app JS from GitHub CDN (via JSDelivr)
4. Calls initializer function with config
5. Vue app mounts into view container
6. App gets user email from `Knack.getUserAttributes().email`
7. Backend creates/syncs vespa_students record automatically
8. All activity operations use email as identifier

---

## 🔄 **Current Authentication Flow**

### **Student Login (Phase 1):**
```javascript
// 1. Student logs into Knack (existing auth)
// 2. Navigate to #vespa-activities
// 3. Vue app loads

// 4. Get user from Knack
const userEmail = Knack.getUserAttributes().email;
const knackAttrs = Knack.getUserAttributes();
// Returns: { 
//   email, 
//   id: "knack_id_here", 
//   first_name, 
//   last_name, 
//   ... 
// }

// 5. Backend API auto-syncs to vespa_students
await fetch('/api/activities/recommended?email=' + userEmail);
// Backend calls: get_or_create_vespa_student(email, knack_attrs)
// Creates record if first time, or updates if Knack ID changed

// 6. All queries use email
const activities = await supabase
  .from('student_activities')
  .select('*')
  .eq('student_email', userEmail);
```

### **Staff Login (Phase 1):**
```javascript
// Same pattern
const staffEmail = Knack.getUserAttributes().email;

// Fetch connected students (from Knack initially)
await fetch('/api/staff/students?staff_email=' + staffEmail + '&role=tutor');

// Backend:
// 1. Queries Knack API for connected students (Object_10 connections)
// 2. Creates/syncs each student in vespa_students
// 3. Creates staff_student_connections records
// 4. Returns student list with activity stats
```

---

## 🐍 **Migration Scripts**

### **Prerequisites:**
```bash
cd migration_scripts
pip install -r requirements.txt

# Create .env file:
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key
KNACK_APP_ID=66e26296d863e5001c6f1e09
KNACK_API_KEY=0b19dcb0-9f43-11ef-8724-eb3bc75b770f
```

### **Run in Order:**
```bash
# 1. Import activities (75 records)
python 01_migrate_activities.py
# Duration: ~2 minutes
# Source: structured_activities_with_thresholds.json

# 2. Import questions (1,573 records)
python 02_migrate_questions.py
# Duration: ~5 minutes
# Source: activityquestion.csv
# Links questions to activities by name

# 3. Update problem mappings
python 03_update_problem_mappings.py
# Duration: ~1 minute
# Source: vespa-problem-activity-mappings1a.json
# Updates activities.problem_mappings array

# 4. Import historical responses (6,060 records)
python 04_migrate_historical_responses.py
# Duration: ~15 minutes
# Source: Knack Object_46 via API
# Filters: completion_date >= 2025-01-01 AND student_email NOT NULL
# Creates vespa_students records as it imports

# 5. Seed achievement definitions (23 achievements)
python 05_seed_achievements.py
# Duration: ~1 minute
# Creates gamification rules
```

### **Verification After Migration:**
```sql
SELECT COUNT(*) FROM activities;  -- Expected: 75
SELECT COUNT(*) FROM activity_questions;  -- Expected: ~1573
SELECT COUNT(*) FROM activity_responses;  -- Expected: ~6060
SELECT COUNT(*) FROM vespa_students;  -- Expected: ~number of unique students
SELECT COUNT(*) FROM achievement_definitions;  -- Expected: 23
```

---

## 🎨 **Vue 3 App Architecture**

### **Student App Components (To Build):**
```
src/components/
├── ActivityDashboard.vue       # Main dashboard
├── ActivityCard.vue             # Single activity card
├── ActivityModal.vue            # Full-screen activity experience
├── CategoryFilter.vue           # Filter by VESPA category
├── ProblemSelector.vue          # Self-selection by problem
├── QuestionRenderer.vue         # Dynamic question rendering
├── ProgressTracker.vue          # Visual progress indicators
├── AchievementPanel.vue         # Achievements/badges display
├── NotificationBell.vue         # Real-time notification dropdown
└── FeedbackPanel.vue            # Staff feedback display
```

### **Composables (Partially Complete):**
```
src/composables/
├── useActivities.js             # ✅ Activity state management
├── useVESPAScores.js            # ✅ Fetch scores from Supabase
├── useNotifications.js          # ✅ Real-time notifications
├── useAchievements.js           # ✅ Achievement tracking
└── useProgress.js               # ⏳ Progress calculations (to build)
```

### **Services (Partially Complete):**
```
src/services/
├── activityService.js           # ✅ Activity CRUD operations
├── supabase.js                  # ✅ Supabase client (in shared/)
└── knackAuth.js                 # ⏳ Knack user detection (to build)
```

### **Build & Deploy:**
```bash
# Build
cd student
npm install
npm run build

# Output: dist/student-activities1a.js + student-activities1a.css

# Push to GitHub
git add .
git commit -m "Student Activities V3 - Version 1a"
git push origin main

# CDN will serve from:
# https://cdn.jsdelivr.net/gh/4Sighteducation/vespa-activities-v3@main/student/dist/student-activities1a.js

# For next version: Change 1a → 1b in vite.config.js
```

---

## 🔗 **Backend API Endpoints (To Implement)**

### **Flask Routes in Dashboard App:**
```python
# GET endpoints
/api/activities/recommended?email=&cycle=1
/api/activities/by-problem?problem_id=
/api/activities/assigned?email=&cycle=1
/api/activities/questions?activity_id=

# POST endpoints
/api/activities/start
/api/activities/save (auto-save every 30s)
/api/activities/complete

# Staff endpoints
/api/staff/students?staff_email=&role=tutor
/api/staff/student-activities?student_email=&cycle=1
/api/staff/assign-activity
/api/staff/feedback
/api/staff/remove-activity
/api/staff/award-achievement

# Notification endpoints
/api/notifications?email=&unread_only=true
/api/notifications/mark-read

# Achievement endpoint
/api/achievements/check?email=
```

### **Backend Implementation Notes:**
- Use Supabase service key for all operations
- Create vespa_students record on first API call if not exists
- Call `get_or_create_vespa_student()` function
- Handle year rollover automatically
- Sync latest VESPA scores on each request
- Check achievements after activity completion

---

## 🎮 **Activity Recommendation Logic**

### **How Activities Are Suggested:**

```python
# Get student's latest VESPA scores
scores = fetch_vespa_scores(email, cycle)
# Returns: {vision: 7, effort: 8, systems: 6, practice: 7, attitude: 9}

# Get student's level
level = scores['level']  # "Level 2" or "Level 3"

# For each category, recommend 3 activities where:
activities = fetch_activities(
  category='Vision',
  level=level,
  score_min <= scores['vision'] <= score_max
)

# Example:
# If vision score = 7:
# - Show activities where score_threshold_min <= 7
# - AND score_threshold_max >= 7
# - OR threshold is NULL (show to everyone)
```

### **Problem-Based Selection:**
```python
# Student clicks "I can't see how school connects to my future"
# Maps to problem_id: "svision_3"

# Fetch activities with this problem_id
activities = fetch_activities(
  problem_mappings CONTAINS ['svision_3']
)

# Returns: ["Success Leaves Clues", "There and Back", "20 Questions", "SMART Goals"]
```

---

## 🏆 **Gamification System**

### **Achievement Types (23 total):**

**Milestones:**
- First Steps (1 activity) = 10 points
- Rising Star (5 activities) = 25 points
- Dedicated Learner (10 activities) = 50 points
- Committed Student (15 activities) = 75 points
- VESPA Champion (20 activities) = 100 points

**Category Masters:**
- Vision Master (80% of Vision activities) = 75 points
- Effort Master, Systems Master, Practice Master, Attitude Master = 75 points each

**Streaks:**
- Getting Started (3 days) = 20 points
- Weekly Warrior (7 days) = 50 points
- Consistency King (14 days) = 100 points
- Unstoppable (30 days) = 200 points

**Quality:**
- Thoughtful Scholar (500+ word reflection) = 25 points
- Detail Oriented (1000+ word reflection) = 50 points

**Speed:**
- Efficient Worker (complete under recommended time) = 20 points

**Ultimate:**
- VESPA Master (complete ALL activities) = 500 points

### **Auto-Award Trigger:**
```python
# After student completes activity:
def complete_activity():
    # 1. Update activity_responses status = 'completed'
    # 2. Increment vespa_students.total_activities_completed
    # 3. Check all achievement_definitions
    # 4. For each unearned achievement:
    #    - Evaluate criteria against student's data
    #    - If met, insert into student_achievements
    #    - Send notification
    #    - Add points to vespa_students.total_points
```

---

## 🔔 **Real-Time Notifications**

### **Notification Types:**
- `feedback_received` - Staff left feedback on activity
- `activity_assigned` - Staff assigned new activity
- `achievement_earned` - New achievement unlocked
- `reminder` - Activity not completed reminder
- `milestone` - Progress milestone reached
- `staff_note` - Custom note from staff
- `encouragement` - Motivational message

### **How It Works:**

**Backend Creates Notification:**
```python
supabase.table('notifications').insert({
  'recipient_email': student_email,
  'recipient_type': 'student',
  'notification_type': 'feedback_received',
  'title': '💬 New Feedback',
  'message': 'Your tutor left feedback on: Perfect Day',
  'action_url': '#vespa-activities?activity=abc123&action=view-feedback',
  'related_response_id': response_id,
  'priority': 'normal'
})
```

**Frontend Receives (Real-time):**
```javascript
// Vue composable subscribes to changes
supabase
  .channel(`notifications:${userEmail}`)
  .on('postgres_changes', {
    event: 'INSERT',
    table: 'notifications',
    filter: `recipient_email=eq.${userEmail}`
  }, (payload) => {
    // Show toast notification
    // Update bell icon badge
    // Play sound (optional)
  })
  .subscribe();
```

---

## 📦 **Next Steps (Immediate)**

### **1. Run Migration Scripts** (30 minutes total)
```bash
cd migration_scripts
python 01_migrate_activities.py      # 75 activities
python 02_migrate_questions.py       # 1,573 questions
python 03_update_problem_mappings.py # Problem links
python 04_migrate_historical_responses.py  # 6,060 responses
python 05_seed_achievements.py       # 23 achievements
```

### **2. Build Vue Student App** (1-2 weeks)
Priority components:
- ActivityDashboard (main view)
- ActivityCard (with progress indicators)
- ActivityModal (full experience with questions)
- QuestionRenderer (handle all question types)
- Auto-save system (every 30 seconds)
- Completion flow with achievement check

### **3. Build Backend API** (1 week)
Priority endpoints:
- GET /api/activities/recommended
- GET /api/activities/assigned
- POST /api/activities/start
- POST /api/activities/save
- POST /api/activities/complete
- GET /api/notifications

### **4. Test & Deploy** (1 week)
- Test with small student group
- Create Knack scenes (scene_1288, scene_1290)
- Update KnackAppLoader
- Deploy to GitHub
- Monitor and iterate

---

## ⚠️ **Important Notes**

### **DO NOT:**
- ❌ Delete or modify legacy `students` table (breaks questionnaire/reports)
- ❌ Try to enforce unique constraints on legacy tables
- ❌ Delete duplicate student records (breaks UUID foreign keys)
- ❌ Change existing foreign key patterns in vespa_scores/question_responses

### **DO:**
- ✅ Use `vespa_students` for all new activity features
- ✅ Use email as identifier everywhere in activities system
- ✅ Auto-sync from Knack on each access
- ✅ Handle year rollovers gracefully
- ✅ Keep legacy system completely separate
- ✅ Plan for eventual Supabase auth migration

### **Key Architectural Principle:**
> "Two systems, one platform: Legacy uses UUID foreign keys, New uses email foreign keys. Both coexist peacefully via the same Supabase project."

---

## 📊 **Data Integrity**

### **vespa_students Guarantees:**
- ✅ Email always unique (enforced)
- ✅ One record per student (forever)
- ✅ All Knack IDs tracked (historical_knack_ids array)
- ✅ Current academic year tracked
- ✅ Multi-year students handled correctly
- ✅ Soft delete support (deleted_at)

### **activity_responses Guarantees:**
- ✅ Unique per student/activity/cycle
- ✅ Full audit trail (started_at, completed_at)
- ✅ Auto-save preserves progress
- ✅ Staff feedback tracked separately
- ✅ Read receipts for feedback

### **Migration Data Quality:**
- Historical responses: Only records since Jan 2025 (6,060 records)
- Only records with valid student email
- Date parsing handles multiple formats
- JSON responses preserved
- Knack IDs preserved for reference

---

## 🔐 **Security & RLS**

### **Row Level Security Configured:**
- Students can only see their own data
- Staff can see connected students only
- Service role (backend) has full access
- Activities and questions are public (read-only)
- Notifications scoped to recipient

### **API Authentication:**
Backend uses Supabase service key (full access) and validates user identity from Knack session.

---

## 🎨 **UI/UX Considerations**

### **Theme Colors (from user memory):**
```javascript
Primary: #079baa (turquoise)
Light: #7bd8d0
Secondary: #62d1d2
Accent: #00e5db
Blue: #5899a8
Dark Blue: #23356f

// Category colors
Vision: #ff8f00 (orange)
Effort: #5899a8 (blue)
Systems: #7bd8d0 (turquoise)
Practice: #8b72be (purple)
Attitude: #ff769c (rose/pink)
```

### **Mobile Responsive:**
- All components must work on mobile
- Touch-friendly buttons
- Collapsible sections
- Optimized for smaller screens

### **Loading States:**
- Show spinners during data fetch
- Auto-save indicator
- Progress bars
- Optimistic UI updates

---

## 📞 **Key Contacts & Resources**

### **Supabase Project:**
- Same project as questionnaire/reports
- URL: (in .env file)
- Service key: (in .env file)

### **Knack Application:**
- App ID: 66e26296d863e5001c6f1e09
- API Key: 0b19dcb0-9f43-11ef-8724-eb3bc75b770f
- URL: https://vespaacademy.knack.com/vespa-academy

### **GitHub Repository:**
- To create: https://github.com/4Sighteducation/vespa-activities-v3
- CDN: https://cdn.jsdelivr.net/gh/4Sighteducation/vespa-activities-v3@main/

### **Backend API:**
- Flask app: https://vespa-dashboard-9a1f84ee5341.herokuapp.com
- Same app as questionnaire/reports backend

---

## 🚨 **Known Issues & Solutions**

### **Issue 1: Duplicate Students in Legacy Table**
**Cause**: Multi-year students, year rollovers  
**Impact**: Can't enforce email uniqueness on legacy table  
**Solution**: Use vespa_students (clean table, unique email enforced)

### **Issue 2: Knack ID Changes Annually**
**Cause**: School deletes/re-imports students each year  
**Impact**: Same student gets new Knack ID  
**Solution**: Track in historical_knack_ids array, update current_knack_id

### **Issue 3: Foreign Keys Use UUIDs (Legacy)**
**Cause**: Original design used student_id (UUID)  
**Impact**: Can't migrate foreign keys without data cleanup  
**Solution**: New system uses student_email (VARCHAR), separate pattern

### **Issue 4: Progress Tracking Bugs (Old System)**
**Cause**: Duplicate API calls, date format errors, race conditions  
**Impact**: Staff can't see student progress  
**Solution**: Complete rewrite in Supabase with proper error handling

---

## ✅ **Success Criteria**

### **Phase 1 Launch:**
- [ ] All 75 activities imported
- [ ] All 1,573 questions imported
- [ ] Historical 6,060 responses imported
- [ ] Student can view recommended activities
- [ ] Student can select activities by problem
- [ ] Student can complete activities with auto-save
- [ ] Progress tracked correctly in Supabase
- [ ] Staff can view connected students
- [ ] Staff can assign/remove activities
- [ ] Staff can give feedback
- [ ] Notifications work (at least in-app)
- [ ] Achievements auto-award
- [ ] Year rollover handled gracefully
- [ ] No bugs from old system (duplicate records, date errors, etc.)

---

## 📚 **Reference Materials**

### **Key JSON Files:**
- `structured_activities_with_thresholds.json` - Complete activity data with HTML
- `activity_json_final1a.json` - Cleaner activity JSON (alternative)
- `vespa-problem-activity-mappings1a.json` - Problem → activity mappings
- `activityquestion.csv` - All 1,573 questions with metadata

### **Old System (For Reference):**
- `VESPAactivitiesStudent4q.js` (7,058 lines) - Current student app
- `VESPAactivitiesStaff8b.js` (6,455 lines) - Current staff app
- Bug reports: `PROGRESS_TRACKING_CRITICAL_ISSUES.md`

### **Related Systems:**
- Questionnaire V2: Uses same Supabase project, different tables
- Reports V2: Uses same Supabase project, different tables
- All share same backend Flask app

---

## 🎯 **Vision Statement**

> "Build a clean, scalable, real-time activities system that solves multi-year student tracking issues, provides instant staff feedback, and creates a migration path to full Supabase independence. Start with activities, expand to all VESPA systems."

---

## 📝 **Status Summary**

**Current Status**: ✅ Database foundation complete  
**Blockers**: None  
**Next Priority**: Run migration scripts to import data  
**Timeline**: 2-4 weeks to MVP  
**Risk Level**: Low (legacy systems unaffected)

---

**Last Updated**: November 11, 2025  
**Document Version**: 1.0  
**Ready for**: New context window, new developer, or continuation

---

## 🚀 **Quick Start for New Context**

1. Read this document completely
2. Review `ARCHITECTURE_VISION.md` for migration phases
3. Check `FUTURE_READY_SCHEMA.sql` ran successfully (query tables)
4. Run migration scripts 01-05 in order
5. Verify data imported correctly
6. Start building Vue components
7. Implement backend API endpoints
8. Test integration
9. Deploy to GitHub
10. Update KnackAppLoader
11. Test in Knack production

**You're building the future of the VESPA platform!** 🎉

Appendix - Knack Field Mappings - 
Object_6 (Student Record)
{
  field_90: 'studentName',                    // Name field
  field_91: 'studentEmail',                   // Email (unique)
  field_179: 'customer',                      // → Object_2 (School)
  field_182: 'vespaResultConnection',         // → Object_10 (VESPA Results)
  field_190: 'connectedStaffAdmins',          // Many-to-many → Object_5
  field_1682: 'connectedTutors',              // Many-to-many → Object_7
  field_547: 'connectedHeadsOfYear',          // Many-to-many → Object_18
  field_2177: 'connectedSubjectTeachers',     // Many-to-many → Object_78
  
  // ** ACTIVITIES FIELDS ** 
  field_1683: 'prescribedActivities',         // Many-to-many → Object_44 (CSV IDs)
  field_1380: 'finishedActivities',           // Short text (CSV of completed activity IDs)
  field_3655: 'newUser',                      // Boolean flag
  field_3656: 'activityHistory',              // Paragraph text (JSON)
  field_1686: 'currentCycle'                  // Cycle number
}
Object_10 (VESPA Results) - VESPA scores per cycle
{
  field_197: 'studentEmail',                  // Email (unique)
  field_187: 'studentName',                   // Proper name field
  field_568: 'level',                         // "Level 2" or "Level 3"
  field_146: 'currentCycle',                  // Current cycle number
  
  // Current scores
  field_147: 'visionScore',                   // Number /10
  field_148: 'effortScore',                   // Number /10
  field_149: 'systemsScore',                  // Number /10
  field_150: 'practiceScore',                 // Number /10
  field_151: 'attitudeScore',                 // Number /10
  
  // Historical scores (Cycle 1, 2, 3)
  field_155: 'visionc1', field_161: 'visionc2', field_167: 'visionc3',
  field_156: 'effortc1', field_162: 'effortc2', field_168: 'effortc3',
  // ... etc for all categories
  
  // Staff connections
  field_439: 'connectedStaffAdmins',          // Many-to-many
  field_145: 'connectedTutors',               // Many-to-many
  field_429: 'connectedHeadsOfYear',          // Many-to-many
  field_2191: 'connectedSubjectTeachers'      // Many-to-many
}

Object_44 (Activities) - Activity library
{
  field_1278: 'activityName',                 // Name (unique)
  field_1285: 'vespaCategory',                // Vision/Effort/Systems/Practice/Attitude
  field_1295: 'activityLevel',                // "Level 2" or "Level 3" (fallback)
  field_3568: 'activityLevelAlt',             // Preferred level field
  field_1287: 'scoreThresholdMin',            // Show if score > X
  field_1294: 'scoreThresholdMax',            // Show if score <= Y
  field_3584: 'curriculumTags',               // CSV tags for filtering
  field_1134: 'description',                  // Paragraph text
  field_1135: 'duration',                     // Short text
  field_1133: 'activityType',                 // Type field
  
  // Activity content fields (not mapped in current docs)
  // Likely includes: instructions, questions, media URLs, etc.
}

Object_46 (Activity Answers) - Student responses to activities

{
  field_1875: 'studentName',                  // Person name
  field_1300: 'activityAnswersJSON',          // Paragraph text (JSON storage)
                                               // Format: {"activityId":{"cycle_1":{"value":"..."}}...}
  field_2334: 'studentResponsesText',         // Paragraph text
  field_2330: 'yesNo',                        // Yes/No field
  field_2068: 'activityAnswers',              // Paragraph text
  field_1301: 'studentConnection',            // → Object_6
  field_1302: 'activityConnection',           // → Object_44
  field_1734: 'staffFeedback',                // Paragraph text
  field_1870: 'completionDate',               // Date/Time
  field_1871: 'customerConnection',           // → Object_2
  field_1872: 'tutorConnection',              // → Object_7
  field_1873: 'staffAdminConnection',         // → Object_5
  field_2331: 'yearGroup',                    // Short text
  field_2332: 'group',                        // Short text
  field_2333: 'faculty'                       // Short text
}
Object_126 (Activity Progress) - NEW tracking system

{
  field_3535: 'progressId',                   // Auto-increment
  field_3534: 'progressName',                 // Short text
  field_3536: 'studentConnection',            // → Object_6
  field_3537: 'activityConnection',           // → Object_44
  field_3538: 'cycleNumber',                  // Number
  field_3539: 'dateAssigned',                 // Date/Time
  field_3540: 'dateStarted',                  // Date/Time
  field_3541: 'dateCompleted',                // Date/Time
  field_3542: 'totalTimeMinutes',             // Number
  field_3543: 'completionStatus',             // Multiple choice: completed/in_progress/assigned/removed
  field_3544: 'staffVerified',                // Yes/No
  field_3545: 'pointsEarned',                 // Number
  field_3546: 'selectedVia',                  // Multiple choice: staff_assigned/student_choice/auto_prescribed
  field_3547: 'staffNotes',                   // Paragraph text
  field_3548: 'studentReflection',            // Paragraph text
  field_3549: 'wordCount'                     // Number
}

Object_127 (Student Achievements) - Gamification badges
{
  field_3551: 'achievementId',                // Auto-increment
  field_3550: 'achievementName',              // Short text
  field_3552: 'studentConnection',            // → Object_6
  field_3553: 'achievementType',              // Multiple choice
  field_3554: 'achievementName',              // Short text
  field_3555: 'achievementDescription',       // Paragraph text
  field_3556: 'dateEarned',                   // Date/Time
  field_3557: 'pointsValue',                  // Number
  field_3558: 'iconEmoji',                    // Short text
  field_3559: 'issuedByStaff',                // → Object_3 (Accounts)
  field_3560: 'criteriaMet'                   // Paragraph text
}
Object_128 (Activity Feedback) - Staff feedback system
{
  field_3562: 'feedbackId',                   // Auto-increment
  field_3561: 'feedbackName',                 // Short text
  field_3563: 'activityProgressConnection',   // → Object_126
  field_3564: 'staffMemberConnection',        // → Object_3
  field_3565: 'feedbackText',                 // Paragraph text
  field_3566: 'feedbackDate',                 // Date/Time
  field_3567: 'feedbackType'                  // Multiple choice
}

Staff Role Objects
Object_5 (Staff Admin):     { field_86: 'email' }
Object_7 (Tutor):           { field_96: 'email' }
Object_18 (Head of Year):   { field_417: 'email' }
Object_78 (Subject Teacher): { field_1879: 'email' }
Object_3 (Accounts):        { field_70: 'email', field_73: 'userRoles' }

Object_45 Activity Questions  - 

{
field_1278 (Activities Name ) // Short Text
field_1289 (Activity Text) // Rich Text
field_1285 (VESPA Category) //Connection
field_1287 (Score to show (If More Than)) //Number
field_1294 (Score to show (If Less Than or Equal To)) // Number
field_1306 (Video Description / Instructions) // Short Text
field_1288 (Activity Video)  // Rich Text (URL)
field_1307 (Slideshow Description / Instructions) // Short Text
field_1293 (Activity Slideshow) // Rich Text
field_2341 (Answer Required?)  // Boolean (Yes/No)
field_1314 (Show in Final Questions Section) // Boolean (Yes/No)
field_1291 (Drop Down Options) // Short Text
field_1290 (Type) // Multiple Choice
field_1286 (Activity) // Short Text
field_1279 (Question Title) // Short Text
field_1310 (Text Above Question) // Rich Text
field_1292 (Acticve?) // Multiple Choice
field_1303 (Order) // Number

}
