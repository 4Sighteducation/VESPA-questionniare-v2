-- Check the ACTUAL schema of activity_questions table
-- Run this to see what columns exist

-- Step 1: Get all columns in activity_questions table
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'activity_questions'
ORDER BY ordinal_position;

-- Step 2: Check if ANY questions exist for 3R's of Habit
SELECT COUNT(*) as question_count
FROM activity_questions
WHERE activity_id = 'b8c9b21a-b88d-412b-8217-e33710e0af78';

-- Step 3: If questions exist, show all columns
SELECT *
FROM activity_questions
WHERE activity_id = 'b8c9b21a-b88d-412b-8217-e33710e0af78'
LIMIT 5;

-- Step 4: Check if there's a separate questions table
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name ILIKE '%question%';

