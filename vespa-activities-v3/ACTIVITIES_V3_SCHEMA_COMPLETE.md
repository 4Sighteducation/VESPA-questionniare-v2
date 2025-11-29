# VESPA Activities V3 - Complete Supabase Schema Documentation

**Date**: November 29, 2025  
**Version**: 3.0  
**Purpose**: Complete reference for V3 Activities Dashboard (Staff & Student)  
**Database**: Supabase (qcdcdzfanrlvdcagmwmg)

---

## 📋 **TABLE OF CONTENTS**

1. [Core Tables](#core-tables)
2. [Data Model Overview](#data-model-overview)
3. [Query Patterns](#query-patterns)
4. [Staff Dashboard Queries](#staff-dashboard-queries)
5. [Student Dashboard Queries](#student-dashboard-queries)
6. [Notification System](#notification-system)
7. [Performance Optimization](#performance-optimization)

---

## 🗄️ **CORE TABLES**

### **1. activities** (Master Catalog)

**Purpose**: Complete catalog of all VESPA activities (migrated from Knack Object_44)

```sql
activities
├── id (UUID, primary key) ← Supabase-generated
├── knack_id (VARCHAR) ← Original Knack Object_44 record ID
├── name (VARCHAR, required) ← Activity name
├── slug (VARCHAR, nullable) ← URL-friendly identifier
├── vespa_category (VARCHAR, required) ← 'Vision', 'Effort', 'Systems', 'Practice', 'Attitude'
├── level (VARCHAR, required) ← 'Level 2', 'Level 3'
├── difficulty (INTEGER) ← 1-3 scale
├── time_minutes (INTEGER) ← Estimated completion time
├── score_threshold_min (INTEGER) ← Show if VESPA score > this
├── score_threshold_max (INTEGER) ← Show if VESPA score <= this
├── content (JSONB, required) ← Structured content (resources, etc.)
├── do_section_html (TEXT) ← "DO" section content
├── think_section_html (TEXT) ← "THINK" section content
├── learn_section_html (TEXT) ← "LEARN" section content
├── reflect_section_html (TEXT) ← "REFLECT" section content
├── problem_mappings (TEXT[]) ← Array of problem IDs this activity addresses
├── curriculum_tags (TEXT[]) ← Curriculum/subject tags
├── color (VARCHAR) ← Display color override
├── display_order (INTEGER) ← Sorting order
├── is_active (BOOLEAN, default: true) ← Only active shown to users
├── created_at (TIMESTAMP)
├── updated_at (TIMESTAMP)
└── created_by_email (VARCHAR) ← Staff who created/imported

**Indexes:**
- PRIMARY KEY on id
- INDEX on vespa_category
- INDEX on level
- INDEX on is_active
- INDEX on knack_id (for migration tracking)

**Row Count**: ~400-500 activities
```

---

### **2. activity_questions** (Questions per Activity)

**Purpose**: Questions that students answer when completing activities (migrated from Knack Object_45)

```sql
activity_questions
├── id (UUID, primary key)
├── activity_id (UUID, FK → activities.id, required) ← Which activity this belongs to
├── question_text (TEXT, required) ← The actual question
├── question_type (VARCHAR) ← 'Short Text', 'Paragraph Text', 'Dropdown', etc.
├── options (TEXT) ← Options for dropdown/multiple choice (comma-separated)
├── display_order (INTEGER, required) ← Order within activity
├── is_required (BOOLEAN) ← Must be answered?
├── is_active (BOOLEAN, default: true)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)

**Indexes:**
- PRIMARY KEY on id
- INDEX on activity_id
- INDEX on is_active WHERE is_active = true
- UNIQUE INDEX on (activity_id, display_order)

**Foreign Keys:**
- activity_id → activities.id (CASCADE on delete)

**Row Count**: ~2,000 questions (~5 questions per activity)
```

---

### **3. activity_responses** (THE MAGIC TABLE)

**Purpose**: Tracks EVERYTHING - assignments, progress, completions, feedback, notifications

**THIS IS THE MOST IMPORTANT TABLE!** It replaces:
- Knack Object_6 field_1683 (prescribed activities)
- Knack Object_6 field_1380 (finished activities)
- Knack Object_46 (Activity Answers)
- Knack Object_126 (Activity Progress)
- Part of Knack Object_128 (Activity Feedback)

```sql
activity_responses
├── id (UUID, primary key)
├── knack_id (VARCHAR, unique) ← Original Knack Object_46 record ID
├── student_email (VARCHAR, required) ← FK to vespa_students.email
├── activity_id (UUID, required) ← FK to activities.id
├── cycle_number (INTEGER, required) ← Which VESPA cycle (1, 2, or 3)
├── academic_year (VARCHAR) ← e.g., "2025/2026"
│
├── -- RESPONSE DATA --
├── responses (JSONB, required) ← Student's answers to questions
│                                  Format: { "question_id": "answer text", ... }
├── responses_text (TEXT) ← Plain text version for searching
│
├── -- STATUS TRACKING --
├── status (VARCHAR) ← 'assigned', 'in_progress', 'completed', 'removed'
├── started_at (TIMESTAMP) ← When student first opened activity
├── completed_at (TIMESTAMP) ← When student finished (NULL = incomplete)
├── time_spent_minutes (INTEGER) ← Time spent (auto-calculated)
├── word_count (INTEGER) ← Total words in responses
│
├── -- ASSIGNMENT TRACKING --
├── selected_via (VARCHAR) ← 'questionnaire', 'staff_assigned', 'student_choice'
│                            THIS IS HOW WE KNOW IF IT'S "PRESCRIBED"!
│
├── -- FEEDBACK & NOTIFICATIONS --
├── staff_feedback (TEXT) ← Staff written feedback
├── staff_feedback_by (VARCHAR) ← Email of staff who gave feedback
├── staff_feedback_at (TIMESTAMP) ← When feedback was given
├── feedback_read_by_student (BOOLEAN) ← Notification system! 🔔
├── feedback_read_at (TIMESTAMP) ← When student viewed feedback
│
├── -- METADATA --
├── year_group (VARCHAR) ← Denormalized from student
├── student_group (VARCHAR) ← Denormalized from student
│
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)

**Indexes:**
- PRIMARY KEY on id
- UNIQUE INDEX on knack_id
- UNIQUE INDEX on (student_email, activity_id, cycle_number) ← Prevents duplicates!
- INDEX on student_email (most common query)
- INDEX on activity_id
- INDEX on status
- INDEX on cycle_number
- INDEX on completed_at WHERE completed_at IS NOT NULL

**Foreign Keys:**
- activity_id → activities.id (CASCADE on delete)
- student_email → vespa_students.email (NO FORMAL FK, just string reference)

**Row Count**: 6,085 responses (2,804 completed, 3,281 in progress)

**Current Data Issues:**
- ⚠️ Some emails have HTML tags (being fixed)
- ⚠️ All have selected_via='student_choice' (staff assignments will add 'staff_assigned')
```

---

### **4. activity_history** (Audit Trail)

**Purpose**: Logs all activity-related actions for audit/analytics

```sql
activity_history
├── id (UUID, primary key)
├── student_email (VARCHAR, required)
├── activity_id (UUID) ← FK to activities.id
├── activity_name (VARCHAR) ← Denormalized for quick display
├── action (VARCHAR, required) ← 'started', 'completed', 'assigned', 'removed', 'feedback_given'
├── triggered_by (VARCHAR) ← 'student', 'staff', 'system'
├── triggered_by_email (VARCHAR) ← Who performed the action
├── cycle_number (INTEGER)
├── academic_year (VARCHAR)
├── metadata (JSONB) ← Additional context
└── timestamp (TIMESTAMP)

**Indexes:**
- PRIMARY KEY on id
- INDEX on student_email
- INDEX on activity_id
- INDEX on action
- INDEX on timestamp DESC

**Foreign Keys:**
- activity_id → activities.id

**Row Count**: Growing continuously (audit trail)
```

---

### **5. vespa_students** (Canonical Student Registry)

**Purpose**: Single source of truth for students in Activities V3  
**Linked to**: vespa_accounts (from Account Management System)

```sql
vespa_students
├── id (UUID, primary key)
├── account_id (UUID, FK → vespa_accounts.id) ← Links to account system!
├── email (VARCHAR, UNIQUE) ← Primary identifier
├── first_name (VARCHAR)
├── last_name (VARCHAR)
├── full_name (VARCHAR, computed)
├── school_id (UUID, FK → establishments.id)
├── school_name (VARCHAR, denormalized)
├── current_year_group (VARCHAR) ← '7', '8', ...'13'
├── student_group (VARCHAR) ← Tutor group
├── current_academic_year (VARCHAR) ← '2025/2026'
├── current_level (VARCHAR) ← 'Level 2', 'Level 3'
├── current_cycle (INTEGER) ← 1, 2, or 3
├── latest_vespa_scores (JSONB) ← Cached scores for performance
│   Format: { "vision": 7.5, "effort": 8.0, ... }
├── total_points (INTEGER) ← Achievement points
├── total_activities_completed (INTEGER) ← Counter
├── current_streak_days (INTEGER)
├── longest_streak_days (INTEGER)
├── status (VARCHAR)
├── is_active (BOOLEAN)
├── last_activity_at (TIMESTAMP) ← Last time they did anything
├── years_in_system (INTEGER)
├── current_knack_id (VARCHAR) ← Current year's Knack ID
├── historical_knack_ids (VARCHAR[]) ← Array of past Knack IDs (year rollovers)
├── supabase_user_id (UUID) ← For future Supabase Auth
├── auth_provider (VARCHAR) ← 'knack' (current) or 'supabase' (future)
├── preferences (JSONB)
├── knack_user_attributes (JSONB)
├── last_synced_from_knack (TIMESTAMP)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)

**Indexes:**
- PRIMARY KEY on id
- UNIQUE INDEX on email
- UNIQUE INDEX on account_id
- INDEX on school_id
- INDEX on current_year_group
- INDEX on is_active WHERE is_active = true

**Foreign Keys:**
- account_id → vespa_accounts.id
- school_id → establishments.id

**Row Count**: 1,806 (students who've used Activities V3)
```

---

### **6. vespa_staff** (Staff Registry)

**Purpose**: Staff members (from Account Management System)  
**Used for**: Finding which students a staff member can access

```sql
vespa_staff
├── id (UUID, primary key)
├── account_id (UUID, FK → vespa_accounts.id)
├── email (VARCHAR, UNIQUE)
├── first_name (VARCHAR)
├── last_name (VARCHAR)
├── school_id (UUID, FK → establishments.id)
├── school_name (VARCHAR, denormalized)
├── department (VARCHAR)
├── position_title (VARCHAR)
├── assigned_tutor_groups (VARCHAR) ← Comma-separated
├── assigned_year_groups (VARCHAR) ← Comma-separated
└── last_synced_from_knack (TIMESTAMP)

**Indexes:**
- PRIMARY KEY on id
- UNIQUE INDEX on email
- UNIQUE INDEX on account_id
- INDEX on school_id

**Row Count**: ~200-500 staff members
```

---

### **7. user_connections** (Staff-Student Links)

**Purpose**: Many-to-many relationship between staff and students  
**Source**: Account Management System V3

```sql
user_connections
├── id (UUID, primary key)
├── staff_account_id (UUID, FK → vespa_accounts.id)
├── student_account_id (UUID, FK → vespa_accounts.id)
├── connection_type (ENUM) ← 'tutor', 'head_of_year', 'subject_teacher', 'staff_admin'
├── context (JSONB) ← Metadata (e.g., subject for subject_teacher)
├── created_at (TIMESTAMP)
└── UNIQUE(staff_account_id, student_account_id, connection_type)

**This is how staff find their students!**
```

---

## 🔗 **DATA MODEL OVERVIEW**

### **Complete Relationship Diagram**

```
┌─────────────────────────────────────────────────────────────┐
│                    ACCOUNT SYSTEM                           │
│                                                             │
│  ┌──────────────────┐                                      │
│  │ vespa_accounts   │ ← Parent for all users               │
│  │ (students+staff) │                                      │
│  └──────────────────┘                                      │
│         │                                                   │
│    ┌────┴────┐                                            │
│    ↓         ↓                                             │
│  ┌────────┐ ┌────────┐         ┌──────────────────┐      │
│  │ vespa_ │ │ vespa_ │────────>│ user_connections │      │
│  │students│ │ staff  │         │ (who sees whom)  │      │
│  └────────┘ └────────┘         └──────────────────┘      │
└─────────────────────────────────────────────────────────────┘
                    ↓ email (string FK)
┌─────────────────────────────────────────────────────────────┐
│                 ACTIVITIES SYSTEM                           │
│                                                             │
│  ┌──────────────────┐                                      │
│  │ activities       │ ← Activity catalog                   │
│  │ (400-500 total)  │   (Object_44 migrated)               │
│  └──────────────────┘                                      │
│         │ FK: activity_id                                  │
│         ↓                                                   │
│  ┌──────────────────┐                                      │
│  │ activity_        │ ← Questions per activity             │
│  │ questions        │   (Object_45 migrated)               │
│  │ (~2000 total)    │                                      │
│  └──────────────────┘                                      │
│         │ FK: activity_id                                  │
│         ↓                                                   │
│  ┌──────────────────────────────────────────────┐         │
│  │ activity_responses (THE MAGIC TABLE!)        │         │
│  │ ~6,085 responses                             │         │
│  │                                               │         │
│  │ Combines:                                     │         │
│  │ • Assignment tracking (status field)          │         │
│  │ • Progress tracking (started_at, time)        │         │
│  │ • Completion tracking (completed_at)          │         │
│  │ • Response storage (responses JSONB)          │         │
│  │ • Feedback system (staff_feedback fields)     │         │
│  │ • Notification system (feedback_read flag)    │         │
│  │ • Origin tracking (selected_via field)        │         │
│  │                                               │         │
│  │ UNIQUE: (student_email, activity_id, cycle)   │         │
│  └──────────────────────────────────────────────┘         │
│         │ Changes logged to                                │
│         ↓                                                   │
│  ┌──────────────────┐                                      │
│  │ activity_history │ ← Audit trail                        │
│  │ (all actions)    │   (who did what when)                │
│  └──────────────────┘                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 **QUERY PATTERNS**

### **Pattern 1: Get All Students with Activity Progress (Staff Dashboard - Page 1)**

```sql
-- Get students with activity counts and progress
SELECT 
  vs.id,
  vs.email,
  vs.first_name,
  vs.last_name,
  vs.full_name,
  vs.current_year_group,
  vs.student_group,
  vs.latest_vespa_scores,
  
  -- Count prescribed activities (questionnaire + staff assigned)
  COUNT(CASE 
    WHEN ar.selected_via IN ('questionnaire', 'staff_assigned') 
    THEN 1 
  END) as prescribed_count,
  
  -- Count completed prescribed
  COUNT(CASE 
    WHEN ar.selected_via IN ('questionnaire', 'staff_assigned') 
    AND ar.completed_at IS NOT NULL 
    THEN 1 
  END) as completed_count,
  
  -- Count all activities (including student choice)
  COUNT(ar.id) as total_activity_count,
  
  -- Count by category (for category breakdown)
  COUNT(CASE WHEN a.vespa_category = 'Vision' AND ar.selected_via IN ('questionnaire', 'staff_assigned') THEN 1 END) as vision_prescribed,
  COUNT(CASE WHEN a.vespa_category = 'Vision' AND ar.selected_via IN ('questionnaire', 'staff_assigned') AND ar.completed_at IS NOT NULL THEN 1 END) as vision_completed,
  
  -- Repeat for other categories...
  
  -- Unread feedback count
  COUNT(CASE 
    WHEN ar.staff_feedback IS NOT NULL 
    AND ar.feedback_read_by_student = false 
    THEN 1 
  END) as unread_feedback_count

FROM vespa_students vs
LEFT JOIN activity_responses ar ON ar.student_email = vs.email
LEFT JOIN activities a ON a.id = ar.activity_id
WHERE vs.school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'::uuid
  AND vs.is_active = true
GROUP BY vs.id, vs.email, vs.first_name, vs.last_name, vs.full_name, 
         vs.current_year_group, vs.student_group, vs.latest_vespa_scores
ORDER BY vs.last_name, vs.first_name;
```

**Supabase JS equivalent:**
```javascript
const { data: students } = await supabase
  .from('vespa_students')
  .select(`
    id,
    email,
    first_name,
    last_name,
    full_name,
    current_year_group,
    student_group,
    latest_vespa_scores,
    activity_responses!inner (
      id,
      activity_id,
      status,
      selected_via,
      completed_at,
      staff_feedback,
      feedback_read_by_student,
      activities (
        id,
        name,
        vespa_category,
        level
      )
    )
  `)
  .eq('school_id', schoolId)
  .eq('is_active', true)
  .order('last_name');

// Calculate client-side (instant!)
students.forEach(student => {
  const responses = student.activity_responses;
  const prescribed = responses.filter(r => 
    r.selected_via === 'questionnaire' || 
    r.selected_via === 'staff_assigned'
  );
  const completed = prescribed.filter(r => r.completed_at);
  
  student.prescribedCount = prescribed.length;
  student.completedCount = completed.length;
  student.progress = prescribed.length > 0 ? 
    (completed.length / prescribed.length * 100) : 0;
  
  // Category breakdown
  student.categoryBreakdown = {
    vision: prescribed.filter(r => r.activities.vespa_category === 'Vision'),
    effort: prescribed.filter(r => r.activities.vespa_category === 'Effort'),
    systems: prescribed.filter(r => r.activities.vespa_category === 'Systems'),
    practice: prescribed.filter(r => r.activities.vespa_category === 'Practice'),
    attitude: prescribed.filter(r => r.activities.vespa_category === 'Attitude')
  };
  
  // Unread feedback
  student.unreadFeedbackCount = responses.filter(r => 
    r.staff_feedback && !r.feedback_read_by_student
  ).length;
});
```

---

### **Pattern 2: Get Single Student with All Activities (Staff Dashboard - Page 2)**

```sql
-- Get student with ALL their activities
SELECT 
  vs.*,
  json_agg(
    json_build_object(
      'id', ar.id,
      'activityId', ar.activity_id,
      'activityName', a.name,
      'category', a.vespa_category,
      'level', a.level,
      'status', ar.status,
      'selectedVia', ar.selected_via,
      'completedAt', ar.completed_at,
      'startedAt', ar.started_at,
      'responses', ar.responses,
      'staffFeedback', ar.staff_feedback,
      'feedbackReadByStudent', ar.feedback_read_by_student,
      'staffFeedbackAt', ar.staff_feedback_at,
      'timeSpentMinutes', ar.time_spent_minutes,
      'wordCount', ar.word_count
    )
  ) FILTER (WHERE ar.id IS NOT NULL) as assigned_activities

FROM vespa_students vs
LEFT JOIN activity_responses ar ON ar.student_email = vs.email
LEFT JOIN activities a ON a.id = ar.activity_id
WHERE vs.email = 'student@school.com'
GROUP BY vs.id;
```

**Supabase JS equivalent:**
```javascript
const { data: studentData } = await supabase
  .from('vespa_students')
  .select(`
    *,
    activity_responses (
      id,
      activity_id,
      status,
      selected_via,
      completed_at,
      started_at,
      responses,
      staff_feedback,
      staff_feedback_by,
      staff_feedback_at,
      feedback_read_by_student,
      feedback_read_at,
      time_spent_minutes,
      word_count,
      created_at,
      activities (
        id,
        name,
        vespa_category,
        level,
        difficulty,
        time_minutes,
        problem_mappings,
        curriculum_tags,
        do_section_html,
        think_section_html,
        learn_section_html,
        reflect_section_html
      )
    )
  `)
  .eq('email', studentEmail)
  .single();
```

---

### **Pattern 3: Get All Available Activities for Assignment**

```sql
-- Get all active activities (for staff to assign)
SELECT 
  id,
  name,
  vespa_category,
  level,
  difficulty,
  time_minutes,
  problem_mappings,
  curriculum_tags,
  score_threshold_min,
  score_threshold_max
FROM activities
WHERE is_active = true
ORDER BY vespa_category, level, display_order;
```

**Supabase JS equivalent:**
```javascript
const { data: allActivities } = await supabase
  .from('activities')
  .select('*')
  .eq('is_active', true)
  .order('vespa_category, level, display_order');
```

---

### **Pattern 4: Assign Activity to Student (Staff Action)**

```sql
-- Staff assigns activity to student
INSERT INTO activity_responses (
  student_email,
  activity_id,
  cycle_number,
  academic_year,
  status,
  selected_via,
  year_group,
  student_group,
  responses
) VALUES (
  'student@school.com',
  'activity-uuid-here',
  1,
  '2025/2026',
  'assigned',
  'staff_assigned',  -- THIS MARKS IT AS PRESCRIBED!
  'Year 12',
  'Form 12A',
  '{}'::jsonb
)
ON CONFLICT (student_email, activity_id, cycle_number) 
DO UPDATE SET
  status = 'assigned',
  selected_via = 'staff_assigned',
  updated_at = NOW();

-- Log the action
INSERT INTO activity_history (
  student_email,
  activity_id,
  action,
  triggered_by,
  triggered_by_email,
  cycle_number,
  academic_year,
  metadata
) VALUES (
  'student@school.com',
  'activity-uuid-here',
  'assigned',
  'staff',
  'teacher@school.com',
  1,
  '2025/2026',
  '{"reason": "staff_prescription"}'::jsonb
);
```

**Supabase JS equivalent:**
```javascript
const { data, error } = await supabase
  .from('activity_responses')
  .upsert({
    student_email: studentEmail,
    activity_id: activityId,
    cycle_number: cycleNumber,
    academic_year: academicYear,
    status: 'assigned',
    selected_via: 'staff_assigned',
    year_group: yearGroup,
    student_group: studentGroup,
    responses: {}
  }, {
    onConflict: 'student_email,activity_id,cycle_number'
  });

// Log to history
await supabase
  .from('activity_history')
  .insert({
    student_email: studentEmail,
    activity_id: activityId,
    action: 'assigned',
    triggered_by: 'staff',
    triggered_by_email: staffEmail,
    cycle_number: cycleNumber,
    academic_year: academicYear
  });
```

---

### **Pattern 5: Remove Activity from Student**

```sql
-- Option A: Soft delete (change status to 'removed')
UPDATE activity_responses
SET 
  status = 'removed',
  updated_at = NOW()
WHERE student_email = 'student@school.com'
  AND activity_id = 'activity-uuid'
  AND cycle_number = 1;

-- Option B: Hard delete (actually remove)
DELETE FROM activity_responses
WHERE student_email = 'student@school.com'
  AND activity_id = 'activity-uuid'
  AND cycle_number = 1;
```

---

### **Pattern 6: Give Feedback on Completed Activity**

```sql
UPDATE activity_responses
SET 
  staff_feedback = 'Excellent reflection on your time management strategies!',
  staff_feedback_by = 'teacher@school.com',
  staff_feedback_at = NOW(),
  feedback_read_by_student = false,  -- Triggers notification! 🔔
  updated_at = NOW()
WHERE id = 'response-uuid';

-- Log feedback action
INSERT INTO activity_history (
  student_email,
  activity_id,
  action,
  triggered_by,
  triggered_by_email,
  metadata
) VALUES (
  'student@school.com',
  'activity-uuid',
  'feedback_given',
  'staff',
  'teacher@school.com',
  '{"feedback_length": 250}'::jsonb
);
```

---

## 🔔 **NOTIFICATION SYSTEM**

### **Unread Feedback Query (Student View)**

```sql
-- Get count of unread feedback
SELECT COUNT(*) as unread_count
FROM activity_responses
WHERE student_email = 'student@school.com'
  AND staff_feedback IS NOT NULL
  AND feedback_read_by_student = false;

-- Get activities with unread feedback (with details)
SELECT 
  ar.id,
  ar.activity_id,
  a.name as activity_name,
  a.vespa_category,
  ar.staff_feedback,
  ar.staff_feedback_by,
  ar.staff_feedback_at,
  ar.completed_at
FROM activity_responses ar
JOIN activities a ON a.id = ar.activity_id
WHERE ar.student_email = 'student@school.com'
  AND ar.staff_feedback IS NOT NULL
  AND ar.feedback_read_by_student = false
ORDER BY ar.staff_feedback_at DESC;
```

**Supabase JS with Real-time:**
```javascript
// Get unread count
const { count } = await supabase
  .from('activity_responses')
  .select('*', { count: 'exact', head: true })
  .eq('student_email', studentEmail)
  .not('staff_feedback', 'is', null)
  .eq('feedback_read_by_student', false);

// Show badge: 🔴 3

// Subscribe to new feedback
supabase
  .channel('feedback-notifications')
  .on('postgres_changes', 
    {
      event: 'UPDATE',
      schema: 'public',
      table: 'activity_responses',
      filter: `student_email=eq.${studentEmail}`
    },
    payload => {
      if (payload.new.staff_feedback && !payload.new.feedback_read_by_student) {
        // Show notification: "New feedback on [Activity Name]!"
        showNotification(payload.new);
      }
    }
  )
  .subscribe();

// Mark as read when student views
await supabase
  .from('activity_responses')
  .update({
    feedback_read_by_student: true,
    feedback_read_at: new Date().toISOString()
  })
  .eq('id', responseId);
```

---

### **Awaiting Response Query (Staff View)**

```sql
-- Get students who have unread feedback (staff needs to follow up)
SELECT 
  vs.email,
  vs.full_name,
  vs.current_year_group,
  COUNT(*) as activities_awaiting_student_read
FROM vespa_students vs
JOIN activity_responses ar ON ar.student_email = vs.email
WHERE vs.school_id = 'school-uuid'
  AND ar.staff_feedback IS NOT NULL
  AND ar.feedback_read_by_student = false
GROUP BY vs.id, vs.email, vs.full_name, vs.current_year_group
ORDER BY activities_awaiting_student_read DESC;
```

---

## 📊 **STAFF DASHBOARD QUERIES**

### **Query 1: My Students (Based on Connection Type)**

```javascript
// Get staff member's account_id
const { data: staffData } = await supabase
  .from('vespa_staff')
  .select('account_id')
  .eq('email', staffEmail)
  .single();

// Get connected students
const { data: myStudents } = await supabase
  .from('user_connections')
  .select(`
    student:vespa_accounts!student_account_id (
      id,
      email,
      vespa_students (
        *,
        activity_responses (
          id,
          activity_id,
          status,
          selected_via,
          completed_at,
          staff_feedback,
          feedback_read_by_student,
          activities (name, vespa_category, level)
        )
      )
    )
  `)
  .eq('staff_account_id', staffData.account_id)
  .eq('connection_type', 'tutor');  // Or 'head_of_year', 'staff_admin'
```

---

### **Query 2: Student Activity Detail (for Workspace View)**

```javascript
const { data } = await supabase
  .from('activity_responses')
  .select(`
    *,
    activities (
      *,
      activity_questions (
        id,
        question_text,
        question_type,
        options,
        display_order,
        is_required
      )
    )
  `)
  .eq('student_email', studentEmail)
  .eq('cycle_number', cycleNumber)
  .order('activities(vespa_category), activities(level)');
```

---

### **Query 3: Activity Statistics (Dashboard Summary)**

```sql
-- Get summary stats for staff dashboard
SELECT 
  COUNT(DISTINCT vs.id) as total_students,
  COUNT(ar.id) as total_assignments,
  COUNT(ar.id) FILTER (WHERE ar.completed_at IS NOT NULL) as total_completed,
  COUNT(ar.id) FILTER (WHERE ar.completed_at IS NULL) as total_incomplete,
  COUNT(ar.id) FILTER (WHERE ar.staff_feedback IS NOT NULL AND ar.feedback_read_by_student = false) as feedback_pending_read,
  AVG(ar.time_spent_minutes) FILTER (WHERE ar.completed_at IS NOT NULL) as avg_time_minutes,
  AVG(ar.word_count) FILTER (WHERE ar.completed_at IS NOT NULL) as avg_word_count
FROM vespa_students vs
LEFT JOIN activity_responses ar ON ar.student_email = vs.email
WHERE vs.school_id = 'school-uuid'
  AND vs.is_active = true;
```

---

## ⚡ **PERFORMANCE OPTIMIZATION**

### **Existing Indexes (Already Optimized!)**
```sql
✅ activity_responses.student_email (most common filter)
✅ activity_responses.activity_id
✅ activity_responses.status
✅ activity_responses.completed_at WHERE completed_at IS NOT NULL
✅ UNIQUE (student_email, activity_id, cycle_number) ← Prevents duplicates!
✅ activities.vespa_category
✅ vespa_students.school_id
✅ vespa_students.email
```

### **Query Performance Tips:**
1. **Use specific SELECT** - Don't SELECT * if you only need a few fields
2. **Filter early** - Add WHERE clauses before JOINs
3. **Limit results** - Use LIMIT for lists
4. **Client-side aggregation** - Let Postgres JOIN, calculate totals in JS

---

## 🎯 **KEY FIELD MAPPINGS (V2 Knack → V3 Supabase)**

| V2 Knack | V3 Supabase | Purpose |
|----------|-------------|---------|
| Object_6.field_1683 (prescribed activities array) | activity_responses WHERE selected_via IN ('questionnaire', 'staff_assigned') | Curriculum activities |
| Object_6.field_1380 (finished activities CSV) | activity_responses WHERE completed_at IS NOT NULL | Completed activities |
| Object_44 (Activities) | activities table | Activity catalog |
| Object_45 (Questions) | activity_questions table | Questions per activity |
| Object_46 (Activity Answers) | activity_responses.responses (JSONB) | Student answers |
| Object_126 (Activity Progress) | activity_responses (same record!) | Progress tracking |
| Object_128 (Activity Feedback) | activity_responses.staff_feedback | Feedback from staff |
| field_3651 (new feedback given) | activity_responses.feedback_read_by_student = false | Notification flag |

---

## 🚀 **V3 ADVANTAGES**

### **vs V2 Knack System:**

| Feature | V2 (Knack) | V3 (Supabase) |
|---------|-----------|---------------|
| **Assignment tracking** | Array in field_1683 | Relational rows with status |
| **Completion tracking** | CSV string in field_1380 | completed_at timestamp |
| **Progress calculation** | Parse arrays, count matches | Simple SQL aggregate |
| **Query speed** | ~5-10 seconds (multiple API calls) | <500ms (single JOIN) |
| **Real-time updates** | Manual refresh only | Supabase subscriptions |
| **Feedback notifications** | Separate Object_128 | Same table, simple flag |
| **Staff filtering** | Complex array queries | RLS + user_connections |
| **Category breakdown** | Calculate in JS after load | Single query with FILTER |

---

## ✅ **READY TO BUILD V3!**

**Next Steps:**
1. **YOU**: Run the email cleanup SQL (with duplicate handling)
2. **ME**: Build V3 Staff Dashboard (Vue 3 + Vite)
3. **ME**: Build V3 Student Dashboard (Vue 3 + Vite)
4. **ME**: Implement notification system
5. **ME**: Add real-time updates (optional)

**Shall I proceed with building the Staff Dashboard?** 🚀
