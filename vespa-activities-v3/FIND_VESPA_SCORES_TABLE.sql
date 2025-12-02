-- Find where VESPA scores are actually stored

-- Step 1: Find all tables with 'vespa' or 'score' in the name
SELECT 
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND (table_name ILIKE '%vespa%' OR table_name ILIKE '%score%' OR table_name ILIKE '%dashboard%')
ORDER BY table_name;

-- Step 2: Check if there's a separate questionnaire results table
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name ILIKE '%question%'
ORDER BY table_name;

-- Step 3: Check student_questionnaire_status table if it exists
-- SELECT * FROM student_questionnaire_status 
-- WHERE student_email IN ('aramsey@vespa.academy', 'portele@gmail.com')
-- LIMIT 5;

-- Step 4: Since scores are NULL, we can either:
-- A) Show activity counts instead of scores (already working!)
-- B) Sync scores from Knack
-- C) Calculate scores from questionnaire responses

-- For now, the Scores toggle showing 0/0 is CORRECT because scores are null
-- You can either:
-- 1. Run Knack → Supabase sync to populate latest_vespa_scores
-- 2. Or just use the Activities toggle (which works perfectly!)

-- Temporary fix: Drop and recreate RPC without scores
-- (Use this if you want to keep scores for later)

DROP FUNCTION IF EXISTS get_connected_students_for_staff(text, uuid, text);

CREATE OR REPLACE FUNCTION get_connected_students_for_staff(
  staff_email_param TEXT,
  school_id_param UUID,
  connection_type_filter TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  email VARCHAR(255),
  first_name VARCHAR(255),
  last_name VARCHAR(255),
  full_name VARCHAR(255),
  current_year_group VARCHAR(255),
  student_group VARCHAR(255),
  gender VARCHAR(50),
  connection_type VARCHAR(50),
  school_id UUID,
  school_name VARCHAR(255),
  account_id UUID,
  latest_vespa_scores JSONB,  -- Include scores (will be null until synced)
  total_activities INTEGER,
  completed_activities INTEGER,
  in_progress_activities INTEGER,
  vision_total INTEGER,
  vision_completed INTEGER,
  effort_total INTEGER,
  effort_completed INTEGER,
  systems_total INTEGER,
  systems_completed INTEGER,
  practice_total INTEGER,
  practice_completed INTEGER,
  attitude_total INTEGER,
  attitude_completed INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  staff_account_id_var UUID;
BEGIN
  SELECT vs.account_id INTO staff_account_id_var
  FROM vespa_staff vs
  WHERE vs.email = staff_email_param 
  AND vs.school_id = school_id_param;
  
  IF staff_account_id_var IS NULL THEN
    RAISE EXCEPTION 'Staff member not found';
  END IF;
  
  RETURN QUERY
  SELECT 
    vs.id,
    vs.email,
    vs.first_name,
    vs.last_name,
    vs.full_name,
    vs.current_year_group,
    vs.student_group,
    vs.gender,
    uc.connection_type,
    vs.school_id,
    vs.school_name,
    vs.account_id,
    vs.latest_vespa_scores,  -- Include JSONB scores
    -- Total counts
    COALESCE(COUNT(ar.id), 0)::INTEGER as total_activities,
    COALESCE(COUNT(ar.id) FILTER (WHERE ar.status = 'completed'), 0)::INTEGER as completed_activities,
    COALESCE(COUNT(ar.id) FILTER (WHERE ar.status = 'in_progress'), 0)::INTEGER as in_progress_activities,
    -- Vision counts
    COALESCE(COUNT(ar.id) FILTER (WHERE a.vespa_category = 'Vision'), 0)::INTEGER as vision_total,
    COALESCE(COUNT(ar.id) FILTER (WHERE a.vespa_category = 'Vision' AND ar.status = 'completed'), 0)::INTEGER as vision_completed,
    -- Effort counts
    COALESCE(COUNT(ar.id) FILTER (WHERE a.vespa_category = 'Effort'), 0)::INTEGER as effort_total,
    COALESCE(COUNT(ar.id) FILTER (WHERE a.vespa_category = 'Effort' AND ar.status = 'completed'), 0)::INTEGER as effort_completed,
    -- Systems counts
    COALESCE(COUNT(ar.id) FILTER (WHERE a.vespa_category = 'Systems'), 0)::INTEGER as systems_total,
    COALESCE(COUNT(ar.id) FILTER (WHERE a.vespa_category = 'Systems' AND ar.status = 'completed'), 0)::INTEGER as systems_completed,
    -- Practice counts
    COALESCE(COUNT(ar.id) FILTER (WHERE a.vespa_category = 'Practice'), 0)::INTEGER as practice_total,
    COALESCE(COUNT(ar.id) FILTER (WHERE a.vespa_category = 'Practice' AND ar.status = 'completed'), 0)::INTEGER as practice_completed,
    -- Attitude counts
    COALESCE(COUNT(ar.id) FILTER (WHERE a.vespa_category = 'Attitude'), 0)::INTEGER as attitude_total,
    COALESCE(COUNT(ar.id) FILTER (WHERE a.vespa_category = 'Attitude' AND ar.status = 'completed'), 0)::INTEGER as attitude_completed
  FROM vespa_students vs
  JOIN user_connections uc ON uc.student_account_id = vs.account_id
  LEFT JOIN activity_responses ar ON ar.student_email = vs.email AND ar.status != 'removed'
  LEFT JOIN activities a ON ar.activity_id = a.id
  WHERE uc.staff_account_id = staff_account_id_var
  AND vs.school_id = school_id_param
  AND (connection_type_filter IS NULL OR uc.connection_type = connection_type_filter)
  GROUP BY vs.id, vs.email, vs.first_name, vs.last_name, vs.full_name, 
           vs.current_year_group, vs.student_group, vs.gender, uc.connection_type,
           vs.school_id, vs.school_name, vs.account_id, vs.latest_vespa_scores
  ORDER BY vs.last_name, vs.first_name;
END;
$$;

