-- Check VESPA scores in Supabase

-- Step 1: Check vespa_students table schema for score fields
SELECT 
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'vespa_students'
  AND column_name LIKE '%score%'
ORDER BY ordinal_position;

-- Step 2: Get sample VESPA scores for a few students
SELECT 
    email,
    full_name,
    vision_score,
    effort_score,
    systems_score,
    practice_score,
    attitude_score
FROM vespa_students
WHERE email IN ('aramsey@vespa.academy', 'portele@gmail.com')
LIMIT 5;

-- Step 3: Check if scores exist for all students
SELECT 
    COUNT(*) FILTER (WHERE vision_score IS NOT NULL) as has_vision,
    COUNT(*) FILTER (WHERE effort_score IS NOT NULL) as has_effort,
    COUNT(*) FILTER (WHERE systems_score IS NOT NULL) as has_systems,
    COUNT(*) FILTER (WHERE practice_score IS NOT NULL) as has_practice,
    COUNT(*) FILTER (WHERE attitude_score IS NOT NULL) as has_attitude,
    COUNT(*) as total_students
FROM vespa_students;

-- Step 4: Check the RPC function that loads students
SELECT 
    proname as function_name,
    prosrc as function_source
FROM pg_proc
WHERE proname = 'get_connected_students_for_staff';

