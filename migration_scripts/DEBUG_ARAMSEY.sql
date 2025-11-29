-- ============================================================================
-- DEBUG: aramsey@vespa.academy - Why No Activities Showing?
-- ============================================================================

-- 1. Does this student exist in vespa_students?
SELECT 
    'vespa_students' as table_name,
    email,
    id,
    total_points,
    total_activities_completed,
    last_synced_from_knack,
    preferences
FROM vespa_students
WHERE email = 'aramsey@vespa.academy';

-- 2. Are there any activities in student_activities for this student?
SELECT 
    'student_activities' as table_name,
    sa.student_email,
    sa.activity_id,
    a.name as activity_name,
    a.vespa_category,
    sa.assigned_by,
    sa.assigned_reason,
    sa.status,
    sa.assigned_at
FROM student_activities sa
LEFT JOIN activities a ON a.id = sa.activity_id
WHERE sa.student_email = 'aramsey@vespa.academy'
ORDER BY sa.assigned_at DESC;

-- 3. Are there any activity_responses for this student?
SELECT 
    'activity_responses' as table_name,
    ar.student_email,
    ar.activity_id,
    a.name as activity_name,
    a.vespa_category,
    ar.status,
    ar.selected_via,
    ar.started_at,
    ar.completed_at,
    ar.time_spent_minutes,
    ar.knack_id as original_knack_id
FROM activity_responses ar
LEFT JOIN activities a ON a.id = ar.activity_id
WHERE ar.student_email = 'aramsey@vespa.academy'
ORDER BY ar.created_at DESC;

-- 4. Check legacy students table for this email
SELECT 
    'students (legacy)' as table_name,
    email,
    id,
    created_at,
    knack_id
FROM students
WHERE email = 'aramsey@vespa.academy'
ORDER BY created_at DESC;

-- 5. Count activities by email pattern
SELECT 
    COUNT(*) as count,
    'student_activities' as source
FROM student_activities
WHERE student_email LIKE '%ramsey%'

UNION ALL

SELECT 
    COUNT(*) as count,
    'activity_responses' as source
FROM activity_responses
WHERE student_email LIKE '%ramsey%';

-- 6. Check if there are ANY students with aramsey pattern
SELECT DISTINCT student_email
FROM student_activities
WHERE student_email LIKE '%ramsey%'
UNION
SELECT DISTINCT student_email
FROM activity_responses
WHERE student_email LIKE '%ramsey%';

-- 7. What does the API call return? (We know from logs it creates vespa_student)
-- Check if vespa_student was created by the API
SELECT 
    email,
    created_at,
    last_synced_from_knack,
    total_points,
    total_activities_completed
FROM vespa_students
WHERE email = 'aramsey@vespa.academy';

-- 8. Check Object_46 historical data for this student
SELECT 
    student_email,
    activity_id,
    a.name as activity_name,
    status,
    selected_via,
    completed_at,
    knack_id as original_object_46_id
FROM activity_responses ar
JOIN activities a ON a.id = ar.activity_id
WHERE student_email = 'aramsey@vespa.academy'
AND knack_id IS NOT NULL  -- Only show records migrated from Object_46
ORDER BY created_at DESC;

