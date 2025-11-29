# 🔍 Investigative SQL Queries for Supabase

**Use these queries in Supabase SQL Editor to check migration progress and data**

---

## 📊 **Quick Overview Queries**

### **1. Overall Counts**
```sql
-- Total counts across all tables
SELECT 
    (SELECT COUNT(*) FROM activities) as activities_count,
    (SELECT COUNT(*) FROM activity_questions) as questions_count,
    (SELECT COUNT(*) FROM activity_responses) as responses_count,
    (SELECT COUNT(*) FROM vespa_students) as students_count,
    (SELECT COUNT(*) FROM achievement_definitions) as achievements_count;
```

### **2. Activities Breakdown**
```sql
-- Activities by category and level
SELECT 
    vespa_category,
    level,
    COUNT(*) as count,
    COUNT(CASE WHEN is_active THEN 1 END) as active_count
FROM activities
GROUP BY vespa_category, level
ORDER BY vespa_category, level;
```

### **3. Questions Breakdown**
```sql
-- Questions by activity
SELECT 
    a.name as activity_name,
    a.vespa_category,
    COUNT(aq.id) as question_count
FROM activities a
LEFT JOIN activity_questions aq ON a.id = aq.activity_id
GROUP BY a.id, a.name, a.vespa_category
ORDER BY question_count DESC, a.name;
```

---

## 🎯 **Activity Responses Investigation**

### **4. Response Counts (During Migration)**
```sql
-- Check how many responses have been migrated so far
SELECT 
    COUNT(*) as total_responses,
    COUNT(DISTINCT student_email) as unique_students,
    COUNT(DISTINCT activity_id) as unique_activities,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_count,
    COUNT(CASE WHEN status = 'in_progress' THEN 1 END) as in_progress_count
FROM activity_responses;
```

### **5. Responses by Activity**
```sql
-- See which activities have the most responses
SELECT 
    a.name as activity_name,
    a.vespa_category,
    COUNT(ar.id) as response_count,
    COUNT(CASE WHEN ar.status = 'completed' THEN 1 END) as completed_count
FROM activities a
LEFT JOIN activity_responses ar ON a.id = ar.activity_id
GROUP BY a.id, a.name, a.vespa_category
HAVING COUNT(ar.id) > 0
ORDER BY response_count DESC
LIMIT 20;
```

### **6. Responses by Student**
```sql
-- See which students have the most responses
SELECT 
    vs.email,
    vs.full_name,
    COUNT(ar.id) as response_count,
    COUNT(CASE WHEN ar.status = 'completed' THEN 1 END) as completed_count,
    MAX(ar.completed_at) as last_completed
FROM vespa_students vs
LEFT JOIN activity_responses ar ON vs.email = ar.student_email
GROUP BY vs.email, vs.full_name
HAVING COUNT(ar.id) > 0
ORDER BY response_count DESC
LIMIT 20;
```

### **7. Responses Over Time**
```sql
-- See responses by completion date (to track migration progress)
SELECT 
    DATE(completed_at) as completion_date,
    COUNT(*) as responses_count
FROM activity_responses
WHERE completed_at IS NOT NULL
GROUP BY DATE(completed_at)
ORDER BY completion_date DESC
LIMIT 30;
```

### **8. Recent Responses**
```sql
-- See most recently migrated responses
SELECT 
    ar.id,
    vs.full_name as student_name,
    a.name as activity_name,
    ar.status,
    ar.completed_at,
    ar.knack_id
FROM activity_responses ar
JOIN vespa_students vs ON ar.student_email = vs.email
JOIN activities a ON ar.activity_id = a.id
ORDER BY ar.created_at DESC
LIMIT 20;
```

---

## 👥 **Students Investigation**

### **9. Students Created During Migration**
```sql
-- See students created from historical responses
SELECT 
    email,
    full_name,
    current_knack_id,
    array_length(historical_knack_ids, 1) as historical_ids_count,
    created_at,
    last_synced_from_knack
FROM vespa_students
ORDER BY created_at DESC
LIMIT 50;
```

### **10. Students with Most Activity History**
```sql
-- Students with most responses
SELECT 
    vs.email,
    vs.full_name,
    vs.current_year_group,
    COUNT(ar.id) as total_responses,
    COUNT(CASE WHEN ar.status = 'completed' THEN 1 END) as completed_responses,
    COUNT(DISTINCT ar.activity_id) as unique_activities_completed
FROM vespa_students vs
LEFT JOIN activity_responses ar ON vs.email = ar.student_email
GROUP BY vs.email, vs.full_name, vs.current_year_group
HAVING COUNT(ar.id) > 0
ORDER BY total_responses DESC
LIMIT 20;
```

---

## 📅 **Migration Progress Tracking**

### **11. Migration Progress by Hour**
```sql
-- Track migration progress (if running now)
SELECT 
    DATE_TRUNC('hour', created_at) as hour,
    COUNT(*) as responses_migrated
FROM activity_responses
WHERE created_at >= NOW() - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', created_at)
ORDER BY hour DESC;
```

### **12. Check for Duplicate Knack IDs**
```sql
-- Verify no duplicate knack_ids in responses (should be unique)
SELECT 
    knack_id,
    COUNT(*) as duplicate_count
FROM activity_responses
WHERE knack_id IS NOT NULL
GROUP BY knack_id
HAVING COUNT(*) > 1;
```

### **13. Responses Missing Required Data**
```sql
-- Find responses that might have data quality issues
SELECT 
    COUNT(*) as total,
    COUNT(CASE WHEN student_email IS NULL THEN 1 END) as missing_email,
    COUNT(CASE WHEN activity_id IS NULL THEN 1 END) as missing_activity,
    COUNT(CASE WHEN knack_id IS NULL THEN 1 END) as missing_knack_id,
    COUNT(CASE WHEN responses::text = '{}' THEN 1 END) as empty_responses
FROM activity_responses;
```

---

## 🎯 **Activity-Specific Queries**

### **14. Most Popular Activities**
```sql
-- Activities with most student responses
SELECT 
    a.name,
    a.vespa_category,
    COUNT(DISTINCT ar.student_email) as unique_students,
    COUNT(ar.id) as total_responses,
    ROUND(AVG(ar.time_spent_minutes), 1) as avg_time_minutes
FROM activities a
JOIN activity_responses ar ON a.id = ar.activity_id
GROUP BY a.id, a.name, a.vespa_category
ORDER BY total_responses DESC
LIMIT 15;
```

### **15. Activities with Staff Feedback**
```sql
-- See which activities have received staff feedback
SELECT 
    a.name as activity_name,
    COUNT(ar.id) as responses_with_feedback,
    COUNT(DISTINCT ar.staff_feedback_by) as unique_staff_members
FROM activities a
JOIN activity_responses ar ON a.id = ar.activity_id
WHERE ar.staff_feedback IS NOT NULL AND ar.staff_feedback != ''
GROUP BY a.id, a.name
ORDER BY responses_with_feedback DESC;
```

---

## 🔍 **Data Quality Checks**

### **16. Check Response Status Distribution**
```sql
-- See distribution of response statuses
SELECT 
    status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM activity_responses
GROUP BY status
ORDER BY count DESC;
```

### **17. Check Cycle Distribution**
```sql
-- See how responses are distributed across cycles
SELECT 
    cycle_number,
    COUNT(*) as response_count,
    COUNT(DISTINCT student_email) as unique_students,
    COUNT(DISTINCT activity_id) as unique_activities
FROM activity_responses
GROUP BY cycle_number
ORDER BY cycle_number;
```

### **18. Responses with Word Count**
```sql
-- See responses with substantial text (word_count > 0)
SELECT 
    COUNT(*) as total_responses,
    COUNT(CASE WHEN word_count > 0 THEN 1 END) as with_word_count,
    COUNT(CASE WHEN word_count > 100 THEN 1 END) as substantial_responses,
    ROUND(AVG(word_count), 0) as avg_word_count,
    MAX(word_count) as max_word_count
FROM activity_responses
WHERE status = 'completed';
```

---

## ⚡ **Real-Time Migration Monitoring**

### **19. Live Migration Progress**
```sql
-- Run this repeatedly to see migration progress
SELECT 
    COUNT(*) as total_migrated,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '1 minute') as last_minute,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '5 minutes') as last_5_minutes,
    COUNT(DISTINCT student_email) as unique_students,
    MAX(created_at) as last_migration_time
FROM activity_responses;
```

### **20. Migration Rate**
```sql
-- Calculate migration rate (responses per minute)
SELECT 
    COUNT(*) as total_responses,
    EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at))) / 60 as minutes_elapsed,
    ROUND(COUNT(*) / NULLIF(EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at))) / 60, 0), 2) as responses_per_minute
FROM activity_responses
WHERE created_at >= NOW() - INTERVAL '1 hour';
```

---

## 🚨 **Error Detection**

### **21. Find Orphaned Responses**
```sql
-- Responses without valid student or activity
SELECT 
    ar.id,
    ar.knack_id,
    ar.student_email,
    ar.activity_id,
    CASE 
        WHEN vs.email IS NULL THEN 'Missing student'
        WHEN a.id IS NULL THEN 'Missing activity'
        ELSE 'OK'
    END as issue
FROM activity_responses ar
LEFT JOIN vespa_students vs ON ar.student_email = vs.email
LEFT JOIN activities a ON ar.activity_id = a.id
WHERE vs.email IS NULL OR a.id IS NULL
LIMIT 20;
```

### **22. Check Date Ranges**
```sql
-- Verify completion dates are reasonable (after Jan 2025)
SELECT 
    MIN(completed_at) as earliest_completion,
    MAX(completed_at) as latest_completion,
    COUNT(*) FILTER (WHERE completed_at < '2025-01-01') as before_2025,
    COUNT(*) FILTER (WHERE completed_at >= '2025-01-01') as after_2025
FROM activity_responses
WHERE completed_at IS NOT NULL;
```

---

## 🔍 **Duplicate Detection**

### **23. Check for Actual Duplicates**
```sql
-- Verify no duplicate (student_email, activity_id, cycle_number) combinations exist
-- Should return 0 rows if constraint is working correctly
SELECT 
    student_email,
    activity_id,
    cycle_number,
    COUNT(*) as duplicate_count,
    array_agg(id) as response_ids
FROM activity_responses
GROUP BY student_email, activity_id, cycle_number
HAVING COUNT(*) > 1;
```

### **24. Check Email Format Issues**
```sql
-- Find responses with HTML in email (shouldn't happen, but check)
SELECT 
    id,
    student_email,
    LEFT(student_email, 50) as email_preview
FROM activity_responses
WHERE student_email LIKE '%<%' OR student_email LIKE '%>%'
LIMIT 20;
```

### **25. Verify Migration Completeness**
```sql
-- Check if all expected records are present
SELECT 
    COUNT(*) as total_responses,
    COUNT(DISTINCT student_email) as unique_students,
    COUNT(DISTINCT activity_id) as unique_activities,
    COUNT(CASE WHEN knack_id IS NOT NULL THEN 1 END) as with_knack_id,
    COUNT(CASE WHEN completed_at IS NOT NULL THEN 1 END) as completed_count
FROM activity_responses;
```

---

## 📈 **Summary Dashboard Query**

### **26. Complete Migration Status**
```sql
-- One query to see everything
SELECT 
    'Activities' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN is_active THEN 1 END) as active_records
FROM activities
UNION ALL
SELECT 
    'Questions' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN is_active THEN 1 END) as active_records
FROM activity_questions
UNION ALL
SELECT 
    'Responses' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as active_records
FROM activity_responses
UNION ALL
SELECT 
    'Students' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN is_active THEN 1 END) as active_records
FROM vespa_students
UNION ALL
SELECT 
    'Achievements' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN is_active THEN 1 END) as active_records
FROM achievement_definitions;
```

---

**💡 Tip**: Run queries 4, 11, and 19 repeatedly during migration to track progress!

