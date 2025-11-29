-- Quick Error Check - Run these to verify migration status

-- 1. Check for actual duplicates (should return 0 rows)
SELECT 
    student_email,
    activity_id,
    cycle_number,
    COUNT(*) as duplicate_count
FROM activity_responses
GROUP BY student_email, activity_id, cycle_number
HAVING COUNT(*) > 1;

-- 2. Overall migration status
SELECT 
    COUNT(*) as total_responses,
    COUNT(DISTINCT student_email) as unique_students,
    COUNT(DISTINCT activity_id) as unique_activities,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_count
FROM activity_responses;

-- 3. Check email format (should return 0 rows if emails are clean)
SELECT COUNT(*) as emails_with_html
FROM activity_responses
WHERE student_email LIKE '%<%' OR student_email LIKE '%>%';

-- 4. Recent migrations
SELECT 
    DATE_TRUNC('hour', created_at) as hour,
    COUNT(*) as responses_migrated
FROM activity_responses
WHERE created_at >= NOW() - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', created_at)
ORDER BY hour DESC;


