-- VESPA Staff Dashboard - SQL Diagnostics
-- Run these in Supabase SQL Editor to check data

-- 1. Check Alena's activity responses
SELECT 
  ar.id,
  ar.status,
  ar.completed_at,
  ar.responses IS NOT NULL as has_responses,
  ar.staff_feedback IS NOT NULL as has_feedback,
  ar.selected_via,
  a.name as activity_name,
  a.vespa_category,
  a.level
FROM activity_responses ar
JOIN activities a ON ar.activity_id = a.id
WHERE ar.student_email = 'aramsey@vespa.academy'
ORDER BY a.vespa_category, a.level;
-- Should show 42-45 rows

-- 2. Check responses JSONB structure for one activity
SELECT 
  a.name,
  ar.responses
FROM activity_responses ar
JOIN activities a ON ar.activity_id = a.id
WHERE ar.student_email = 'aramsey@vespa.academy'
  AND ar.responses IS NOT NULL
  AND ar.responses != '{}'::jsonb
LIMIT 1;
-- Check if responses JSONB has data

-- 3. Check activity questions exist
SELECT 
  aq.id,
  aq.question_text,
  aq.question_type,
  a.name as activity_name
FROM activity_questions aq
JOIN activities a ON aq.activity_id = a.id
WHERE a.name = '3Rs of Habit'
ORDER BY aq.display_order;
-- Should show questions for clicked activity

-- 4. Test RPC function
SELECT * FROM get_student_activity_responses(
  'aramsey@vespa.academy',
  'tut7@vespa.academy',
  'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
)
WHERE activity_name = '3Rs of Habit';
-- Should return activity data with responses

-- 5. Check if responses field is properly structured
SELECT 
  ar.id,
  ar.responses,
  jsonb_pretty(ar.responses) as responses_formatted
FROM activity_responses ar
WHERE ar.student_email = 'aramsey@vespa.academy'
  AND ar.responses IS NOT NULL
  AND ar.responses != '{}'::jsonb
LIMIT 3;
-- See actual JSON structure

-- 6. Count activities by status
SELECT 
  status,
  COUNT(*) as count
FROM activity_responses
WHERE student_email = 'aramsey@vespa.academy'
GROUP BY status;
-- Shows how many in_progress vs completed

