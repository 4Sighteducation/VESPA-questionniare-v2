-- Check if removal is actually working in database
-- Run this AFTER trying to drag-drop remove "Chunking Steps"

-- Step 1: Check the activity responses for Alena Ramsey
SELECT 
    ar.id,
    ar.student_email,
    ar.activity_id,
    a.name as activity_name,
    ar.status,  -- Should be 'removed' if drag-drop worked
    ar.cycle_number,
    ar.updated_at
FROM activity_responses ar
JOIN activities a ON a.id = ar.activity_id
WHERE ar.student_email = 'aramsey@vespa.academy'
  AND a.name = 'Chunking Steps'
ORDER BY ar.updated_at DESC;

-- Step 2: Check activity_history for remove action
SELECT 
    ah.id,
    ah.student_email,
    ah.activity_id,
    a.name as activity_name,
    ah.action,
    ah.triggered_by,
    ah.triggered_by_email,
    ah.created_at
FROM activity_history ah
JOIN activities a ON a.id = ah.activity_id
WHERE ah.student_email = 'aramsey@vespa.academy'
  AND ah.action = 'removed'
ORDER BY ah.created_at DESC
LIMIT 5;

-- Step 3: Count total vs removed activities for Alena
SELECT 
    COUNT(*) FILTER (WHERE status != 'removed') as active_count,
    COUNT(*) FILTER (WHERE status = 'removed') as removed_count,
    COUNT(*) as total_count
FROM activity_responses
WHERE student_email = 'aramsey@vespa.academy';

-- Step 4: Check the RPC function definition
SELECT 
    proname as function_name,
    prosrc as function_source
FROM pg_proc
WHERE proname = 'get_student_activity_responses';

