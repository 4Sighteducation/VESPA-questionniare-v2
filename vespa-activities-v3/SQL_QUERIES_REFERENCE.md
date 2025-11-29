# VESPA Activities V3 - SQL Queries Reference

**Quick reference for common database queries**

---

## 🔍 **VERIFICATION QUERIES**

### **Check Database Health**

```sql
-- Count records in each table
SELECT 'activities' as table_name, COUNT(*) as count FROM activities WHERE is_active = true
UNION ALL
SELECT 'activity_questions', COUNT(*) FROM activity_questions WHERE is_active = true
UNION ALL
SELECT 'activity_responses', COUNT(*) FROM activity_responses
UNION ALL
SELECT 'vespa_students', COUNT(*) FROM vespa_students WHERE is_active = true
UNION ALL
SELECT 'vespa_staff', COUNT(*) FROM vespa_staff
UNION ALL
SELECT 'user_connections', COUNT(*) FROM user_connections;
```

### **Check Data Quality**

```sql
-- Verify no HTML in emails
SELECT COUNT(*) as emails_with_html
FROM activity_responses
WHERE student_email LIKE '%<%' OR student_email LIKE '%mailto:%';
-- Should return 0!

-- Check for duplicates
SELECT 
  student_email,
  activity_id,
  cycle_number,
  COUNT(*) as duplicate_count
FROM activity_responses
GROUP BY student_email, activity_id, cycle_number
HAVING COUNT(*) > 1;
-- Should return no rows!

-- Verify selected_via values
SELECT 
  selected_via,
  COUNT(*) as count
FROM activity_responses
WHERE selected_via IS NOT NULL
GROUP BY selected_via;
-- Should see: questionnaire, staff_assigned, student_choice
```

---

## 👨‍🏫 **STAFF QUERIES**

### **Find Staff Member's Students**

```sql
-- Get all students connected to a staff member
SELECT 
  vs.full_name,
  vs.email,
  vs.current_year_group,
  vs.student_group,
  uc.connection_type
FROM user_connections uc
JOIN vespa_accounts staff_acc ON staff_acc.id = uc.staff_account_id
JOIN vespa_accounts student_acc ON student_acc.id = uc.student_account_id
JOIN vespa_students vs ON vs.account_id = student_acc.id
WHERE staff_acc.email = 'teacher@school.com'
ORDER BY vs.last_name, vs.first_name;
```

### **Check Staff Roles**

```sql
-- Get all roles for a staff member
SELECT 
  vs.email,
  vs.school_name,
  vs.department,
  vs.assigned_tutor_groups,
  ur.role_type
FROM vespa_staff vs
LEFT JOIN user_roles ur ON ur.account_id = vs.account_id
WHERE vs.email = 'teacher@school.com';
```

---

## 🎓 **STUDENT QUERIES**

### **Get Student with All Activities**

```sql
-- Complete student profile with activities
SELECT 
  vs.full_name,
  vs.email,
  vs.current_year_group,
  vs.student_group,
  vs.latest_vespa_scores,
  COUNT(ar.id) as total_activities,
  COUNT(ar.id) FILTER (WHERE ar.completed_at IS NOT NULL) as completed_count,
  COUNT(ar.id) FILTER (WHERE ar.selected_via IN ('questionnaire', 'staff_assigned')) as prescribed_count,
  COUNT(ar.id) FILTER (WHERE ar.selected_via IN ('questionnaire', 'staff_assigned') AND ar.completed_at IS NOT NULL) as prescribed_completed
FROM vespa_students vs
LEFT JOIN activity_responses ar ON ar.student_email = vs.email
WHERE vs.email = 'student@school.com'
GROUP BY vs.id;
```

### **Get Student's Activity List**

```sql
-- List all activities for a student
SELECT 
  a.name as activity_name,
  a.vespa_category,
  a.level,
  ar.status,
  ar.selected_via,
  ar.completed_at,
  ar.started_at,
  ar.staff_feedback IS NOT NULL as has_feedback,
  ar.feedback_read_by_student
FROM activity_responses ar
JOIN activities a ON a.id = ar.activity_id
WHERE ar.student_email = 'student@school.com'
  AND ar.status != 'removed'
ORDER BY a.vespa_category, a.level, a.display_order;
```

---

## 📊 **PROGRESS QUERIES**

### **Calculate Student Progress**

```sql
-- Accurate progress calculation
WITH prescribed AS (
  SELECT *
  FROM activity_responses
  WHERE student_email = 'student@school.com'
    AND selected_via IN ('questionnaire', 'staff_assigned')
    AND status != 'removed'
),
completed AS (
  SELECT *
  FROM prescribed
  WHERE completed_at IS NOT NULL
)
SELECT 
  (SELECT COUNT(*) FROM prescribed) as prescribed_count,
  (SELECT COUNT(*) FROM completed) as completed_count,
  ROUND((SELECT COUNT(*) FROM completed)::numeric / NULLIF((SELECT COUNT(*) FROM prescribed), 0) * 100, 0) as progress_percentage;
```

### **Category Breakdown**

```sql
-- Progress by VESPA category
SELECT 
  a.vespa_category,
  COUNT(*) as prescribed,
  COUNT(*) FILTER (WHERE ar.completed_at IS NOT NULL) as completed,
  ROUND(
    COUNT(*) FILTER (WHERE ar.completed_at IS NOT NULL)::numeric / 
    NULLIF(COUNT(*), 0) * 100, 
    0
  ) as percentage
FROM activity_responses ar
JOIN activities a ON a.id = ar.activity_id
WHERE ar.student_email = 'student@school.com'
  AND ar.selected_via IN ('questionnaire', 'staff_assigned')
  AND ar.status != 'removed'
GROUP BY a.vespa_category
ORDER BY a.vespa_category;
```

---

## 🔔 **NOTIFICATION QUERIES**

### **Unread Feedback Count**

```sql
-- How many activities have unread feedback?
SELECT COUNT(*) as unread_feedback_count
FROM activity_responses
WHERE student_email = 'student@school.com'
  AND staff_feedback IS NOT NULL
  AND feedback_read_by_student = false;
```

### **Students Awaiting Feedback Read**

```sql
-- Which students haven't read your feedback?
SELECT 
  ar.student_email,
  vs.full_name,
  COUNT(*) as unread_feedback_count,
  MAX(ar.staff_feedback_at) as last_feedback_given
FROM activity_responses ar
JOIN vespa_students vs ON vs.email = ar.student_email
WHERE ar.staff_feedback_by = 'teacher@school.com'
  AND ar.feedback_read_by_student = false
GROUP BY ar.student_email, vs.full_name
ORDER BY last_feedback_given DESC;
```

---

## 📈 **ANALYTICS QUERIES**

### **School Summary**

```sql
-- Overall school activity statistics
SELECT 
  COUNT(DISTINCT vs.id) as total_students,
  COUNT(ar.id) as total_assignments,
  COUNT(ar.id) FILTER (WHERE ar.completed_at IS NOT NULL) as total_completed,
  ROUND(AVG(ar.time_spent_minutes) FILTER (WHERE ar.completed_at IS NOT NULL), 0) as avg_time_minutes,
  ROUND(AVG(ar.word_count) FILTER (WHERE ar.completed_at IS NOT NULL), 0) as avg_word_count,
  COUNT(ar.id) FILTER (WHERE ar.staff_feedback IS NOT NULL) as feedback_given_count,
  COUNT(ar.id) FILTER (WHERE ar.staff_feedback IS NOT NULL AND ar.feedback_read_by_student = false) as feedback_unread_count
FROM vespa_students vs
LEFT JOIN activity_responses ar ON ar.student_email = vs.email
WHERE vs.school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'::uuid
  AND vs.is_active = true;
```

### **Most Popular Activities**

```sql
-- Which activities are assigned most?
SELECT 
  a.name,
  a.vespa_category,
  a.level,
  COUNT(*) as times_assigned,
  COUNT(*) FILTER (WHERE ar.completed_at IS NOT NULL) as times_completed,
  ROUND(
    COUNT(*) FILTER (WHERE ar.completed_at IS NOT NULL)::numeric / 
    NULLIF(COUNT(*), 0) * 100, 
    0
  ) as completion_rate
FROM activity_responses ar
JOIN activities a ON a.id = ar.activity_id
WHERE ar.status != 'removed'
GROUP BY a.id, a.name, a.vespa_category, a.level
ORDER BY times_assigned DESC
LIMIT 20;
```

### **Staff Activity Summary**

```sql
-- Which staff members are most active?
SELECT 
  staff_feedback_by as staff_email,
  COUNT(DISTINCT student_email) as students_given_feedback,
  COUNT(*) as total_feedback_given,
  MIN(staff_feedback_at) as first_feedback,
  MAX(staff_feedback_at) as latest_feedback
FROM activity_responses
WHERE staff_feedback_by IS NOT NULL
GROUP BY staff_feedback_by
ORDER BY total_feedback_given DESC;
```

---

## 🛠️ **MAINTENANCE QUERIES**

### **Clean Old Data**

```sql
-- Find activities that were removed over 6 months ago
SELECT 
  id,
  student_email,
  activity_id,
  updated_at
FROM activity_responses
WHERE status = 'removed'
  AND updated_at < NOW() - INTERVAL '6 months'
ORDER BY updated_at;
-- Consider archiving or deleting these
```

### **Find Inactive Students**

```sql
-- Students who haven't done activities in 3+ months
SELECT 
  vs.full_name,
  vs.email,
  vs.last_activity_at,
  COUNT(ar.id) FILTER (WHERE ar.status = 'assigned') as pending_activities
FROM vespa_students vs
LEFT JOIN activity_responses ar ON ar.student_email = vs.email
WHERE vs.is_active = true
  AND (vs.last_activity_at < NOW() - INTERVAL '3 months' OR vs.last_activity_at IS NULL)
GROUP BY vs.id, vs.full_name, vs.email, vs.last_activity_at
ORDER BY vs.last_activity_at NULLS FIRST;
```

### **Orphaned Records**

```sql
-- Find activity_responses without valid student
SELECT 
  ar.student_email,
  COUNT(*) as orphaned_responses
FROM activity_responses ar
LEFT JOIN vespa_students vs ON vs.email = ar.student_email
WHERE vs.id IS NULL
GROUP BY ar.student_email;
-- Should be 0!
```

---

## 🔧 **ADMIN OPERATIONS**

### **Reset Student Progress (Dangerous!)**

```sql
-- ONLY USE IF YOU KNOW WHAT YOU'RE DOING!
-- This removes all activities for a student
UPDATE activity_responses
SET status = 'removed', updated_at = NOW()
WHERE student_email = 'student@school.com';

-- Or permanently delete (cannot undo!)
-- DELETE FROM activity_responses WHERE student_email = 'student@school.com';
```

### **Bulk Assign Activity to Year Group**

```sql
-- Assign one activity to all Year 12 students
INSERT INTO activity_responses (
  student_email,
  activity_id,
  cycle_number,
  academic_year,
  status,
  selected_via,
  year_group,
  responses
)
SELECT 
  vs.email,
  'activity-uuid-here'::uuid,
  1,
  '2025/2026',
  'assigned',
  'staff_assigned',
  vs.current_year_group,
  '{}'::jsonb
FROM vespa_students vs
WHERE vs.current_year_group = 'Year 12'
  AND vs.is_active = true
  AND vs.school_id = 'school-uuid'::uuid
ON CONFLICT (student_email, activity_id, cycle_number) DO NOTHING;
```

---

## 📊 **REPORTING QUERIES**

### **Weekly Activity Report**

```sql
-- Activities completed in the past week
SELECT 
  DATE(ar.completed_at) as completion_date,
  COUNT(*) as activities_completed,
  COUNT(DISTINCT ar.student_email) as unique_students,
  ROUND(AVG(ar.time_spent_minutes), 0) as avg_time_minutes
FROM activity_responses ar
WHERE ar.completed_at >= NOW() - INTERVAL '7 days'
  AND ar.completed_at IS NOT NULL
GROUP BY DATE(ar.completed_at)
ORDER BY completion_date;
```

### **Student Engagement Report**

```sql
-- Which students are most engaged?
SELECT 
  vs.full_name,
  vs.email,
  vs.current_year_group,
  COUNT(ar.id) as total_activities,
  COUNT(ar.id) FILTER (WHERE ar.completed_at IS NOT NULL) as completed,
  ROUND(
    COUNT(ar.id) FILTER (WHERE ar.completed_at IS NOT NULL)::numeric / 
    NULLIF(COUNT(ar.id), 0) * 100, 
    0
  ) as completion_rate,
  MAX(ar.completed_at) as last_completed_at
FROM vespa_students vs
LEFT JOIN activity_responses ar ON ar.student_email = vs.email
WHERE vs.school_id = 'school-uuid'::uuid
  AND vs.is_active = true
  AND ar.status != 'removed'
GROUP BY vs.id, vs.full_name, vs.email, vs.current_year_group
ORDER BY completed DESC;
```

---

## 🎯 **QUICK LOOKUPS**

### **Find a Student**

```sql
-- Search by name or email
SELECT id, email, full_name, current_year_group, school_name
FROM vespa_students
WHERE (full_name ILIKE '%smith%' OR email ILIKE '%smith%')
  AND is_active = true
LIMIT 10;
```

### **Find an Activity**

```sql
-- Search activities by name or category
SELECT id, name, vespa_category, level, time_minutes
FROM activities
WHERE name ILIKE '%time management%'
  AND is_active = true
LIMIT 10;
```

### **Check Activity Assignment Status**

```sql
-- Is this activity assigned to this student?
SELECT 
  ar.status,
  ar.selected_via,
  ar.started_at,
  ar.completed_at,
  a.name
FROM activity_responses ar
JOIN activities a ON a.id = ar.activity_id
WHERE ar.student_email = 'student@school.com'
  AND ar.activity_id = 'activity-uuid'::uuid
  AND ar.cycle_number = 1;
```

---

## 🔄 **USEFUL VIEWS** (Create These!)

### **Student Activity Summary View**

```sql
CREATE OR REPLACE VIEW student_activity_summary AS
SELECT 
  vs.id as student_id,
  vs.email,
  vs.full_name,
  vs.current_year_group,
  vs.student_group,
  vs.school_id,
  COUNT(ar.id) FILTER (WHERE ar.selected_via IN ('questionnaire', 'staff_assigned')) as prescribed_count,
  COUNT(ar.id) FILTER (WHERE ar.selected_via IN ('questionnaire', 'staff_assigned') AND ar.completed_at IS NOT NULL) as completed_count,
  ROUND(
    COUNT(ar.id) FILTER (WHERE ar.selected_via IN ('questionnaire', 'staff_assigned') AND ar.completed_at IS NOT NULL)::numeric /
    NULLIF(COUNT(ar.id) FILTER (WHERE ar.selected_via IN ('questionnaire', 'staff_assigned')), 0) * 100,
    0
  ) as progress_percentage,
  COUNT(ar.id) FILTER (WHERE ar.staff_feedback IS NOT NULL AND ar.feedback_read_by_student = false) as unread_feedback_count,
  MAX(ar.completed_at) as last_completed_at
FROM vespa_students vs
LEFT JOIN activity_responses ar ON ar.student_email = vs.email AND ar.status != 'removed'
WHERE vs.is_active = true
GROUP BY vs.id, vs.email, vs.full_name, vs.current_year_group, vs.student_group, vs.school_id;

-- Then query it:
SELECT * FROM student_activity_summary 
WHERE school_id = 'school-uuid'::uuid
ORDER BY progress_percentage DESC;
```

---

## 🚨 **EMERGENCY QUERIES**

### **Find Broken References**

```sql
-- Activity responses with missing activities
SELECT 
  ar.id,
  ar.student_email,
  ar.activity_id,
  ar.status
FROM activity_responses ar
LEFT JOIN activities a ON a.id = ar.activity_id
WHERE a.id IS NULL;
-- Should be 0!

-- Activity responses with missing students
SELECT 
  ar.id,
  ar.student_email,
  ar.activity_id
FROM activity_responses ar
LEFT JOIN vespa_students vs ON vs.email = ar.student_email
WHERE vs.id IS NULL;
-- If found, students need to be synced from Knack
```

### **Fix Broken Data**

```sql
-- Remove responses for deleted activities
DELETE FROM activity_responses
WHERE activity_id NOT IN (SELECT id FROM activities);

-- Update student emails that changed (careful!)
UPDATE activity_responses
SET student_email = 'newemail@school.com'
WHERE student_email = 'oldemail@school.com';
```

---

## 🎯 **DASHBOARD PERFORMANCE QUERIES**

### **Query Used by Page 1 (Student List)**

```sql
-- This is what the Vue app queries:
SELECT 
  vs.id,
  vs.email,
  vs.first_name,
  vs.last_name,
  vs.full_name,
  vs.current_year_group,
  vs.student_group,
  vs.latest_vespa_scores,
  json_agg(
    json_build_object(
      'id', ar.id,
      'activity_id', ar.activity_id,
      'status', ar.status,
      'selected_via', ar.selected_via,
      'completed_at', ar.completed_at,
      'staff_feedback', ar.staff_feedback,
      'feedback_read_by_student', ar.feedback_read_by_student,
      'activity_name', a.name,
      'activity_category', a.vespa_category,
      'activity_level', a.level
    )
  ) FILTER (WHERE ar.id IS NOT NULL) as activity_responses
FROM vespa_students vs
LEFT JOIN activity_responses ar ON ar.student_email = vs.email AND ar.status != 'removed'
LEFT JOIN activities a ON a.id = ar.activity_id
WHERE vs.school_id = 'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'::uuid
  AND vs.is_active = true
GROUP BY vs.id
ORDER BY vs.last_name, vs.first_name;
```

**Performance**: ~300-500ms for 500 students

---

## 📋 **INDEX VERIFICATION**

```sql
-- Verify all important indexes exist
SELECT
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('activity_responses', 'activities', 'vespa_students', 'vespa_staff', 'user_connections')
ORDER BY tablename, indexname;
```

**Expected indexes:**
- ✅ activity_responses.student_email
- ✅ activity_responses.activity_id
- ✅ activity_responses.status
- ✅ activity_responses (student_email, activity_id, cycle_number) UNIQUE
- ✅ activities.vespa_category
- ✅ activities.level
- ✅ vespa_students.email UNIQUE
- ✅ vespa_students.school_id

---

## 🔒 **RLS POLICY CHECKS**

```sql
-- View all RLS policies on activity tables
SELECT 
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename IN ('activity_responses', 'activities', 'activity_questions', 'vespa_students')
ORDER BY tablename, policyname;
```

**Required policies:**
- ✅ Students can read/update own responses
- ✅ Staff can read students via user_connections
- ✅ Service role has full access
- ✅ Anyone can view active activities/questions

---

## 💡 **TIPS & TRICKS**

### **Test Queries in Supabase Dashboard**

1. Go to: https://supabase.com/dashboard/project/qcdcdzfanrlvdcagmwmg/editor
2. Click "SQL Editor"
3. Paste query
4. Click "Run"

### **Explain Query Performance**

```sql
EXPLAIN ANALYZE
SELECT * FROM activity_responses 
WHERE student_email = 'student@school.com';

-- Look for "Index Scan" (good) vs "Seq Scan" (bad)
```

### **Monitor Slow Queries**

```sql
-- Find queries taking >1 second (if you have pg_stat_statements enabled)
SELECT 
  calls,
  mean_exec_time,
  query
FROM pg_stat_statements
WHERE mean_exec_time > 1000
ORDER BY mean_exec_time DESC
LIMIT 10;
```

---

**Use these queries to:**
- ✅ Verify database health
- ✅ Debug issues
- ✅ Monitor performance
- ✅ Generate reports
- ✅ Maintain data quality

**Happy querying! 🚀**

