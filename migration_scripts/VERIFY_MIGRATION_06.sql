-- ============================================================================
-- VERIFICATION QUERIES FOR MIGRATION STEP 06
-- Student Activities Migration from Knack to Supabase
-- ============================================================================

-- ============================================================================
-- 1. OVERALL COUNTS - Quick Status Check
-- ============================================================================
SELECT 
    'student_activities' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT student_email) as unique_students,
    COUNT(DISTINCT activity_id) as unique_activities
FROM student_activities

UNION ALL

SELECT 
    'activity_responses' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT student_email) as unique_students,
    COUNT(DISTINCT activity_id) as unique_activities
FROM activity_responses

UNION ALL

SELECT 
    'vespa_students' as table_name,
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE preferences IS NOT NULL) as with_preferences,
    COUNT(*) FILTER (WHERE last_synced_from_knack IS NOT NULL) as synced_from_knack
FROM vespa_students;


-- ============================================================================
-- 2. STUDENT_ACTIVITIES - By Assignment Type
-- ============================================================================
SELECT 
    assigned_by,
    status,
    COUNT(*) as count
FROM student_activities
GROUP BY assigned_by, status
ORDER BY assigned_by, status;


-- ============================================================================
-- 3. ACTIVITY_RESPONSES - By Status
-- ============================================================================
SELECT 
    status,
    COUNT(*) as count,
    COUNT(DISTINCT student_email) as unique_students
FROM activity_responses
GROUP BY status
ORDER BY 
    CASE status
        WHEN 'completed' THEN 1
        WHEN 'in_progress' THEN 2
        WHEN 'assigned' THEN 3
        ELSE 4
    END;


-- ============================================================================
-- 4. TEST SPECIFIC STUDENT (354355@nptcgroup.ac.uk)
-- ============================================================================
-- Check student record
SELECT 
    email,
    total_points,
    total_activities_completed,
    preferences,
    last_synced_from_knack
FROM vespa_students
WHERE email = '354355@nptcgroup.ac.uk';

-- Check their assigned activities
SELECT 
    sa.assigned_by,
    sa.assigned_reason,
    sa.status,
    a.name as activity_name,
    a.vespa_category,
    a.level
FROM student_activities sa
JOIN activities a ON a.id = sa.activity_id
WHERE sa.student_email = '354355@nptcgroup.ac.uk'
ORDER BY sa.assigned_at;

-- Check their completed activities
SELECT 
    ar.status,
    ar.selected_via,
    a.name as activity_name,
    ar.completed_at,
    ar.time_spent_minutes
FROM activity_responses ar
JOIN activities a ON a.id = ar.activity_id
WHERE ar.student_email = '354355@nptcgroup.ac.uk'
ORDER BY ar.created_at;


-- ============================================================================
-- 5. TOP STUDENTS BY ACTIVITY COUNT
-- ============================================================================
SELECT 
    student_email,
    COUNT(*) as total_activities,
    COUNT(*) FILTER (WHERE status = 'assigned') as assigned,
    COUNT(*) FILTER (WHERE status = 'completed') as completed
FROM student_activities
GROUP BY student_email
ORDER BY total_activities DESC
LIMIT 20;


-- ============================================================================
-- 6. ACTIVITIES WITH MOST ASSIGNMENTS
-- ============================================================================
SELECT 
    a.name,
    a.vespa_category,
    COUNT(*) as times_assigned,
    COUNT(DISTINCT sa.student_email) as unique_students
FROM student_activities sa
JOIN activities a ON a.id = sa.activity_id
GROUP BY a.id, a.name, a.vespa_category
ORDER BY times_assigned DESC
LIMIT 20;


-- ============================================================================
-- 7. CHECK FOR ORPHANED RECORDS
-- ============================================================================
-- Student activities with no matching activity
SELECT COUNT(*) as orphaned_student_activities
FROM student_activities sa
LEFT JOIN activities a ON a.id = sa.activity_id
WHERE a.id IS NULL;

-- Activity responses with no matching activity
SELECT COUNT(*) as orphaned_activity_responses
FROM activity_responses ar
LEFT JOIN activities a ON a.id = ar.activity_id
WHERE a.id IS NULL;


-- ============================================================================
-- 8. STUDENTS WITH PREFERENCES SET
-- ============================================================================
SELECT 
    email,
    preferences->>'completed_first_activity' as completed_first,
    preferences->>'notifications_enabled' as notifications,
    preferences->>'migrated_from_knack' as migrated,
    last_synced_from_knack
FROM vespa_students
WHERE preferences IS NOT NULL
LIMIT 20;


-- ============================================================================
-- 9. RECENT MIGRATION ACTIVITY
-- ============================================================================
-- Students synced in last 24 hours
SELECT 
    COUNT(*) as students_synced_last_24h
FROM vespa_students
WHERE last_synced_from_knack > NOW() - INTERVAL '24 hours';

-- Activity assignments created recently
SELECT 
    DATE(created_at) as date,
    COUNT(*) as assignments_created
FROM student_activities
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;


-- ============================================================================
-- 10. QUICK SANITY CHECK
-- ============================================================================
-- Should match number of students with activity data in Knack
SELECT 
    (SELECT COUNT(DISTINCT student_email) FROM student_activities) as students_with_activities,
    (SELECT COUNT(DISTINCT student_email) FROM activity_responses WHERE status = 'completed') as students_with_completions,
    (SELECT COUNT(*) FROM vespa_students WHERE last_synced_from_knack IS NOT NULL) as students_synced_from_knack;


-- ============================================================================
-- 11. EXPECTED VS ACTUAL (For Test Student)
-- ============================================================================
-- Test student should have:
-- - 10 prescribed activities (field_1683)
-- - 3 finished activities (field_1380)

SELECT 
    'Expected' as type,
    10 as prescribed_count,
    3 as finished_count
    
UNION ALL

SELECT 
    'Actual' as type,
    (SELECT COUNT(*) FROM student_activities WHERE student_email = '354355@nptcgroup.ac.uk') as prescribed_count,
    (SELECT COUNT(*) FROM activity_responses WHERE student_email = '354355@nptcgroup.ac.uk' AND status = 'completed') as finished_count;

