-- SQL to check "3R's of Habit" activity questions in Supabase
-- Run this in Supabase SQL Editor

-- Step 1: Find the activity ID for "3R's of Habit"
SELECT 
    id,
    name,
    vespa_category,
    level,
    is_active
FROM activities
WHERE name ILIKE '%3R%Habit%'
   OR name ILIKE '%3R''s of Habit%';

-- Step 2: Get all questions for this activity (replace UUID with actual ID from step 1)
-- You'll need to replace 'ACTIVITY_ID_HERE' with the actual UUID from above
SELECT 
    id,
    activity_id,
    question_text,
    display_order,
    is_active,
    old_question_id,
    created_at
FROM activity_questions
WHERE activity_id IN (
    SELECT id FROM activities WHERE name ILIKE '%3R%Habit%'
)
ORDER BY display_order;

-- Step 3: Check what response data exists for this activity
-- This shows what question IDs are being stored in the responses JSON
SELECT 
    ar.id as response_id,
    ar.student_email,
    ar.activity_id,
    a.name as activity_name,
    ar.status,
    ar.completed_at,
    ar.responses,
    jsonb_object_keys(ar.responses) as question_keys_used
FROM activity_responses ar
JOIN activities a ON a.id = ar.activity_id
WHERE a.name ILIKE '%3R%Habit%'
  AND ar.responses IS NOT NULL
  AND ar.responses != '{}'::jsonb
LIMIT 5;

-- Step 4: Compare question IDs in responses vs actual questions
-- This will show which question IDs are in the responses but NOT in activity_questions
WITH habit_activity AS (
    SELECT id FROM activities WHERE name ILIKE '%3R%Habit%' LIMIT 1
),
response_keys AS (
    SELECT DISTINCT jsonb_object_keys(responses) as question_key
    FROM activity_responses
    WHERE activity_id IN (SELECT id FROM habit_activity)
      AND responses IS NOT NULL
),
actual_questions AS (
    SELECT id::text as question_id, old_question_id
    FROM activity_questions
    WHERE activity_id IN (SELECT id FROM habit_activity)
)
SELECT 
    rk.question_key,
    CASE 
        WHEN aq.question_id IS NOT NULL THEN '✅ Found by ID'
        WHEN aq2.question_id IS NOT NULL THEN '✅ Found by old_question_id'
        ELSE '❌ NOT FOUND'
    END as status,
    aq.question_id as current_id,
    aq2.old_question_id as old_id
FROM response_keys rk
LEFT JOIN actual_questions aq ON aq.question_id = rk.question_key
LEFT JOIN actual_questions aq2 ON aq2.old_question_id = rk.question_key;

-- Step 5: Get specific response for Alena Ramsey (test user)
SELECT 
    ar.id,
    ar.student_email,
    ar.activity_id,
    a.name as activity_name,
    ar.responses,
    ar.status,
    ar.completed_at,
    jsonb_pretty(ar.responses) as pretty_responses
FROM activity_responses ar
JOIN activities a ON a.id = ar.activity_id
WHERE ar.student_email = 'aramsey@vespa.academy'
  AND a.name ILIKE '%3R%Habit%';

-- Step 6: If questions exist, show their details with old IDs
SELECT 
    aq.id,
    aq.activity_id,
    a.name as activity_name,
    aq.question_text,
    aq.display_order,
    aq.old_question_id,
    aq.is_active
FROM activity_questions aq
JOIN activities a ON a.id = aq.activity_id
WHERE a.name ILIKE '%3R%Habit%'
ORDER BY aq.display_order;

