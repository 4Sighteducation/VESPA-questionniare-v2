# VESPA Activities V3 - Architecture Understanding & Mapping

**Date**: November 2025  
**Status**: Architecture Review & Clarification  
**Goal**: Complete migration from Knack Objects 44/45/46 to Supabase with Vue 3 apps

---

## 📋 **My Understanding Summary**

### **Current State**
- ✅ Database schema designed (`FUTURE_READY_SCHEMA.sql`)
- ✅ Migration scripts written (Python)
- ⏳ Vue apps scaffolded but incomplete
- ❌ IIFE wrapping not yet configured in vite.config.js
- ❌ Backend API endpoints not implemented
- ❌ Data migration not run

### **Architecture Pattern**
Following the same pattern as Questionnaire V2:
- Vue 3 apps loaded via KnackAppLoader
- IIFE wrapped to prevent DOM conflicts
- Global initializer function exposed
- Supabase as primary data store
- Knack auth only (Phase 1)
- Email-based foreign keys (not UUIDs)

---

## 🗺️ **Knack Field Mappings - My Understanding**

### **Object_44 (Activities) → `activities` table**

| Knack Field | Field ID | Type | Supabase Column | Source Priority | Notes |
|-------------|----------|------|-----------------|-----------------|-------|
| Activity Name | `field_1278` | Text | `name` | **PRIMARY** | Unique identifier, links to Object_45 |
| DO Section | `field_1289` | Rich Text | `do_section_html` | **PRIMARY** | Rich HTML with links/PDFs |
| THINK Section | `field_1288` | Rich Text | `think_section_html` | **PRIMARY** | Videos/slides (YouTube/Google Slides embeds) |
| LEARN Section | `field_1293` | Rich Text | `learn_section_html` | **PRIMARY** | Educational content |
| REFLECT Section | `field_1313` | Rich Text | `reflect_section_html` | **PRIMARY** | Final thoughts |
| VESPA Category | `field_1285` | Connection | `vespa_category` | **PRIMARY** | Vision/Effort/Systems/Practice/Attitude |
| Score More Than | `field_1287` | Number | `score_threshold_min` | **PRIMARY** | Show if VESPA score > X |
| Score Less/Equal | `field_1294` | Number | `score_threshold_max` | **PRIMARY** | Show if VESPA score <= Y |
| Level (Preferred) | `field_3568` | Text | `level` | **PREFERRED** | "Level 2" or "Level 3" |
| Level (Fallback) | `field_1295` | Text | `level` | **FALLBACK** | Use if field_3568 empty |
| Difficulty | `field_1298` | Number | `difficulty` | **PRIMARY** | 0-10 scale |
| Color | `field_1308` | Text | `color` | **PRIMARY** | "Vespa Rose", "Vespa Sky Blue", etc. |
| Active | `field_1299` | Yes/No | `is_active` | **PRIMARY** | Active/inactive flag |
| Display Order | `field_2072` | Number | `display_order` | **PRIMARY** | Sort order |
| Record ID | `id` | Auto | `knack_id` | **PRIMARY** | Original Knack ID |

**✅ Better Source**: `structured_activities_with_thresholds.json` contains:
- All 75 activities with complete HTML
- Pre-structured sections (do/think/learn/reflect)
- Links already extracted
- Thresholds included
- **RECOMMENDATION**: Use JSON file instead of Knack API for migration

---

### **Object_45 (Questions) → `activity_questions` table**

| Knack Field | Field ID | Type | Supabase Column | Notes |
|-------------|----------|------|-----------------|-------|
| Activity | `field_1286` | Connection | `activity_id` | **KEY LINK** - Links to Object_44 by name (field_1278) |
| Question Title | `field_1279` | Text | `question_title` | The actual question text |
| Text Above Question | `field_1310` | Rich Text | `text_above_question` | HTML instructions/context |
| Type | `field_1290` | Multiple Choice | `question_type` | Dropdown/Paragraph Text/Short Text/Date/Checkboxes |
| Dropdown Options | `field_1291` | Text | `dropdown_options` | CSV → Convert to TEXT[] array |
| Order | `field_1303` | Number | `display_order` | Sort order within activity |
| Active | `field_1292` | Multiple Choice | `is_active` | True/False |
| Answer Required | `field_2341` | Yes/No | `answer_required` | Validation flag |
| Show in Final | `field_1314` | Yes/No | `show_in_final_questions` | Display in summary section |

**✅ CSV Source**: `activityquestion.csv` (1,573 records)
- Already has all fields
- Activity name in "Activity" column (links to Object_44.field_1278)
- Can be imported directly to Supabase

**⚠️ CLARIFICATION NEEDED**: 
- Does `field_1286` store the activity **name** (text) or **ID** (connection)?
- CSV shows "Activity" column - is this name or ID?

---

### **Object_46 (Answers) → `activity_responses` table**

| Knack Field | Field ID | Type | Supabase Column | Notes |
|-------------|----------|------|-----------------|-------|
| Student | `field_1301` | Connection → Object_6 | `student_email` | **KEY** - Extract email from connection |
| Activity | `field_1302` | Connection → Object_44 | `activity_id` | Link to activities.id (UUID) |
| Activity Answers JSON | `field_1300` | Paragraph | `responses` | JSON format: `{"activityId":{"cycle_1":{"value":"..."}}...}` |
| Student Responses | `field_2334` | Paragraph | `responses_text` | Concatenated text for search |
| Completion Date | `field_1870` | Date/Time | `completed_at` | When finished |
| Staff Feedback | `field_1734` | Paragraph | `staff_feedback` | Feedback text |
| Tutor | `field_1872` | Connection → Object_7 | `staff_feedback_by` | Tutor email |
| Staff Admin | `field_1873` | Connection → Object_5 | `staff_feedback_by` | Admin email (if tutor empty) |
| Year Group | `field_2331` | Text | `year_group` | Context (denormalized) |
| Group | `field_2332` | Text | `student_group` | Context (denormalized) |
| Record ID | `id` | Auto | `knack_id` | Original Object_46 ID |

**Migration Filter**:
- `completion_date >= 2025-01-01` (field_1870)
- `student_email IS NOT NULL` (from field_1301 connection)
- Expected: ~6,060 records

**⚠️ CLARIFICATION NEEDED**:
- Does `field_1300` store responses per question or per activity?
- Format: `{"activityId":{"cycle_1":{"questionId":"answer"}}}` or simpler?
- How do we map question IDs from Object_45 to the JSON structure?

---

### **Object_126 (Activity Progress) - NEW in Knack**

| Knack Field | Field ID | Type | Supabase Equivalent | Notes |
|-------------|----------|------|---------------------|-------|
| Student | `field_3536` | Connection → Object_6 | `student_email` | Links to vespa_students |
| Activity | `field_3537` | Connection → Object_44 | `activity_id` | Links to activities |
| Cycle Number | `field_3538` | Number | `cycle_number` | 1, 2, or 3 |
| Date Assigned | `field_3539` | Date/Time | `assigned_at` | When assigned |
| Date Started | `field_3540` | Date/Time | `started_at` | When started |
| Date Completed | `field_3541` | Date/Time | `completed_at` | When finished |
| Total Time | `field_3542` | Number | `time_spent_minutes` | Minutes spent |
| Status | `field_3543` | Multiple Choice | `status` | completed/in_progress/assigned/removed |
| Selected Via | `field_3546` | Multiple Choice | `selected_via` | staff_assigned/student_choice/auto_prescribed |
| Staff Notes | `field_3547` | Paragraph | `staff_feedback` | Staff notes |
| Word Count | `field_3549` | Number | `word_count` | Calculated from responses |

**⚠️ QUESTION**: 
- Should we migrate Object_126 data too, or only use it as reference?
- Or ignore it completely and rebuild in Supabase?

---

### **Object_127 (Achievements) - NEW in Knack**

| Knack Field | Field ID | Type | Supabase Equivalent | Notes |
|-------------|----------|------|---------------------|-------|
| Student | `field_3552` | Connection → Object_6 | `student_email` | Links to vespa_students |
| Achievement Type | `field_3553` | Multiple Choice | `achievement_type` | milestone/streak/category_master/custom |
| Achievement Name | `field_3554` | Text | `achievement_name` | Name of achievement |
| Description | `field_3555` | Paragraph | `achievement_description` | Description |
| Date Earned | `field_3556` | Date/Time | `date_earned` | When earned |
| Points Value | `field_3557` | Number | `points_value` | Points awarded |
| Icon Emoji | `field_3558` | Text | `icon_emoji` | Emoji icon |
| Issued By Staff | `field_3559` | Connection → Object_3 | `issued_by_staff` | Staff email (NULL if auto) |
| Criteria Met | `field_3560` | Paragraph | `criteria_met` | JSON criteria |

**⚠️ QUESTION**: 
- Migrate existing achievements from Object_127?
- Or start fresh with new achievement system?

---

## 🏗️ **Complete Architecture Map**

### **Data Flow**

```
┌─────────────────────────────────────────────────────────────┐
│                    KNACK AUTHENTICATION                       │
│              (Phase 1: Knack only, Phase 2+: Dual)           │
└───────────────────────┬───────────────────────────────────────┘
                        │
                        │ Knack.getUserAttributes()
                        │ Returns: { email, id, first_name, ... }
                        │
        ┌───────────────┴───────────────┐
        │                               │
        ▼                               ▼
┌───────────────┐              ┌───────────────┐
│ STUDENT APP  │              │  STAFF APP    │
│ scene_1288   │              │ scene_1290    │
│ view_3262    │              │ view_3268     │
│ #vespa-      │              │ #activity-    │
│ activities   │              │ monitor       │
└───────┬───────┘              └───────┬───────┘
        │                               │
        │ Vue 3 App (IIFE wrapped)     │ Vue 3 App (IIFE wrapped)
        │                               │
        │ Get email from Knack          │ Get email from Knack
        │                               │
        ▼                               ▼
┌─────────────────────────────────────────────────────────────┐
│              BACKEND API (Flask - Heroku)                    │
│  https://vespa-dashboard-9a1f84ee5341.herokuapp.com        │
│                                                             │
│  Endpoints:                                                 │
│  - GET  /api/activities/recommended?email=&cycle=          │
│  - GET  /api/activities/by-problem?problem_id=             │
│  - GET  /api/activities/assigned?email=&cycle=             │
│  - POST /api/activities/start                              │
│  - POST /api/activities/save                                │
│  - POST /api/activities/complete                           │
│  - GET  /api/staff/students?staff_email=&role=             │
│  - POST /api/staff/assign-activity                          │
│  - POST /api/staff/feedback                                │
│  - GET  /api/notifications?email=                           │
└───────────────────────┬───────────────────────────────────────┘
                        │
                        │ Uses Supabase Service Key
                        │ Auto-creates vespa_students records
                        │
        ┌───────────────┴───────────────┐
        │                               │
        ▼                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    SUPABASE DATABASE                        │
│                                                             │
│  Core Tables:                                               │
│  ✅ activities (75)                                        │
│  ✅ activity_questions (1,573)                             │
│  ✅ vespa_students (auto-created on first access)          │
│  ✅ activity_responses (6,060 historical)                   │
│  ✅ student_activities (prescribed/assigned)               │
│  ✅ student_achievements (gamification)                   │
│  ✅ staff_student_connections (many-to-many)               │
│  ✅ notifications (real-time)                              │
│  ✅ activity_history (audit log)                           │
│  ✅ achievement_definitions (rules engine)                 │
│                                                             │
│  Foreign Keys:                                              │
│  - All use student_email (VARCHAR) NOT student_id (UUID)   │
│  - Separate from legacy students table                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 **Activity Recommendation Logic**

### **Score-Based Recommendations**

```javascript
// 1. Get student's latest VESPA scores from Supabase
const scores = await fetchVESPAScores(email, cycle);
// Returns: { vision: 7, effort: 8, systems: 6, practice: 7, attitude: 9, level: "Level 3" }

// 2. For each category, find activities where:
const recommended = await supabase
  .from('activities')
  .select('*')
  .eq('vespa_category', 'Vision')
  .eq('level', scores.level)
  .or(`score_threshold_min.is.null,score_threshold_min.lte.${scores.vision}`)
  .or(`score_threshold_max.is.null,score_threshold_max.gte.${scores.vision}`)
  .eq('is_active', true)
  .order('display_order');

// 3. Show top 3 per category
```

### **Problem-Based Selection**

```javascript
// Student clicks: "I can't see how school connects to my future"
// Maps to problem_id: "svision_3"

// Fetch from problem mappings JSON:
const problemMappings = await fetch('vespa-problem-activity-mappings1a.json');
const problem = problemMappings.problemMappings.Vision.find(p => p.id === 'svision_3');
// Returns: { recommendedActivities: ["Success Leaves Clues", "There and Back", ...] }

// Fetch activities by name:
const activities = await supabase
  .from('activities')
  .select('*')
  .in('name', problem.recommendedActivities)
  .eq('is_active', true);
```

**✅ MUST MAINTAIN**: This self-selection system is already working well!

---

## 🎯 **Staff Dashboard Improvements**

### **Current Issues** (from your description)
- ❌ Progress tracking bugs
- ❌ Loading issues
- ❌ Staff pages not working well

### **Proposed Features**

1. **Student Overview**
   - List all connected students (by role: tutor/staff_admin/head_of_year/subject_teacher)
   - Filter by year group, cycle, status
   - Quick stats: activities completed, points, achievements

2. **Activity Management**
   - Assign activities to students
   - Remove activities
   - View student's activity progress
   - See completion status (assigned/started/completed)

3. **Feedback System**
   - Add feedback on completed activities
   - See if student has read feedback (read receipts)
   - Feedback history per student

4. **Notifications & Reminders**
   - Send reminders to students
   - Trigger notifications for incomplete activities
   - Custom messages/encouragement

5. **Achievements & Certificates**
   - Manually award achievements
   - View all student achievements
   - Generate certificates (future)

6. **Progress Tracking**
   - Visual progress indicators
   - Time spent per activity
   - Word count tracking
   - Completion rates

---

## 🔧 **Technical Implementation**

### **IIFE Wrapping** (CRITICAL - Currently Missing!)

**Current vite.config.js** (student):
```javascript
// ❌ MISSING: format: 'iife'
output: {
  entryFileNames: 'student-activities1a.js',
  // No format specified - defaults to ES modules
}
```

**Required Fix**:
```javascript
output: {
  format: 'iife',  // ✅ Wrap in IIFE
  name: 'VESPAStudentActivities',  // Global name
  entryFileNames: 'student-activities1a.js',
  // ...
}
```

**main.js Pattern** (following Questionnaire V2):
```javascript
// ✅ Expose global initializer
window.initializeStudentActivitiesV3 = function() {
  const config = window.STUDENT_ACTIVITIES_V3_CONFIG;
  // ... mount Vue app
};
```

---

### **KnackAppLoader Integration**

**Scene/View Mapping**:
- **Student**: `scene_1288` / `view_3262` / `#vespa-activities`
- **Staff**: `scene_1290` / `view_3268` / `#activity-monitor`

**✅ CONFIRMED** (User Clarification): 
- Student: `scene_1288` / `view_3262` / `#vespa-activities`
- Staff: `scene_1290` / `view_3268` / `#activity-monitor`

---

## ❓ **Questions for Clarification**

### **1. Data Migration** ✅ CLARIFIED
- ✅ Use `structured_activities_with_thresholds.json` for activities (confirmed in ACTIVITY_PLA1.md)
- ✅ Import `activityquestion.csv` directly to Supabase (confirmed)
- ✅ Link questions to activities by **name** (CSV "Activity" column → activities.name)
- ✅ Object_46 field_1300: JSON structure `{"activityId":{"cycle_1":{"value":"..."}}...}` (from migration script)

### **2. Object_126 & Object_127** ✅ CLARIFIED
- **Object_126**: Not mentioned in ACTIVITY_PLA1.md migration scripts - likely start fresh in Supabase
- **Object_127**: Not mentioned in migration - likely start fresh with new achievement system
- **Recommendation**: Start fresh in Supabase (cleaner, better structure)

### **3. Scene/View Numbers** ✅ CONFIRMED (User Clarification)
- Student: `scene_1288` / `view_3262` / `#vespa-activities` ✅
- Staff: `scene_1290` / `view_3268` / `#activity-monitor` ✅

### **4. Staff Connections** ✅ CLARIFIED
- Backend API endpoint `/api/staff/students` queries `staff_student_connections` table
- Initial sync: Query Knack Object_6 connections on first staff login
- Auto-create `staff_student_connections` records from Knack connections
- Roles: tutor/staff_admin/head_of_year/subject_teacher (from Object_6 field mappings)

### **5. VESPA Scores** ✅ CLARIFIED
- Fetch from existing `vespa_scores` table (legacy) ✅
- Backend endpoint `/api/activities/recommended` queries `vespa_scores` table
- Query by `student_email` and `cycle_number`
- Use scores to calculate recommended activities based on thresholds

### **6. Problem Mappings** ✅ CLARIFIED
- Use existing `vespa-problem-activity-mappings1a.json` ✅
- Load from CDN URL: `https://cdn.jsdelivr.net/gh/4Sighteducation/vespa-activities-v3@main/shared/vespa-problem-activity-mappings1a.json`
- Also stored in Supabase `activities.problem_mappings` TEXT[] array (for querying)
- Dual approach: JSON for frontend, Supabase array for backend queries

### **7. Authentication Flow** ✅ CLARIFIED
- Phase 1: Knack only ✅
- Auto-create `vespa_students` on first API call ✅ (via backend helper function)
- Handle year rollover (update `current_knack_id`) ✅
- Sync student data: Backend should sync name, year group, etc. from Knack Object_6 on first access
- Use `get_or_create_vespa_student()` function (mentioned in handover doc)

---

## 🚀 **Proposed Next Steps**

### **Phase 1: Fix & Complete Foundation** (1-2 days)
1. ✅ Fix vite.config.js - Add IIFE wrapping
2. ✅ Update main.js - Add global initializer function
3. ✅ Verify KnackAppLoader config matches scenes
4. ✅ Test app loading in Knack

### **Phase 2: Data Migration** (1 day)
1. ✅ Run migration scripts (01-05)
2. ✅ Verify data counts
3. ✅ Test queries

### **Phase 3: Backend API** (1 week)
1. ✅ Implement Flask endpoints
2. ✅ Auto-create vespa_students
3. ✅ Handle staff connections
4. ✅ Activity recommendation logic
5. ✅ Problem-based selection

### **Phase 4: Vue Components** (2 weeks)
1. ✅ Student dashboard
2. ✅ Activity modal with questions
3. ✅ Staff dashboard
4. ✅ Feedback system
5. ✅ Notifications
6. ✅ Achievements

### **Phase 5: Testing & Deployment** (1 week)
1. ✅ Test in Knack
2. ✅ Fix bugs
3. ✅ Deploy to GitHub
4. ✅ Update KnackAppLoader

---

## ✅ **Architecture Decisions - RESOLVED**

1. **Object_126 Migration**: Start fresh in Supabase ✅
2. **Object_127 Migration**: Start fresh with new achievement system ✅
3. **Scene Numbers**: Confirmed - Staff: `scene_1290` / `view_3268` / `#activity-monitor` ✅
4. **Question Linking**: By name (CSV "Activity" column → activities.name) ✅
5. **JSON Structure**: `{"activityId":{"cycle_1":{"value":"..."}}...}` ✅
6. **Staff Sync**: Query Knack Object_6 on first login, create `staff_student_connections` ✅

---

**Ready for your feedback and clarifications!** 🎯

