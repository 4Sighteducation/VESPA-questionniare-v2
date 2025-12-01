-- Fixed RPC function for removal - correct return types
-- Drop old version first
DROP FUNCTION IF EXISTS remove_activity_from_student(TEXT, UUID, INT, TEXT, UUID);

-- Create with correct return types matching table schema
CREATE OR REPLACE FUNCTION remove_activity_from_student(
  p_student_email TEXT,
  p_activity_id UUID,
  p_cycle_number INT,
  p_staff_email TEXT,
  p_school_id UUID
)
RETURNS TABLE (
  id UUID,
  student_email VARCHAR(255),  -- Changed from TEXT to match table
  activity_id UUID,
  status VARCHAR(255),          -- Changed from TEXT to match table
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  staff_verified BOOLEAN;
  student_verified BOOLEAN;
BEGIN
  -- Verify staff is in the school
  SELECT EXISTS(
    SELECT 1 FROM vespa_staff
    WHERE email = p_staff_email AND school_id = p_school_id
  ) INTO staff_verified;
  
  IF NOT staff_verified THEN
    RAISE EXCEPTION 'Staff not authorized for this school';
  END IF;
  
  -- Verify student is in the school
  SELECT EXISTS(
    SELECT 1 FROM vespa_students
    WHERE email = p_student_email AND school_id = p_school_id
  ) INTO student_verified;
  
  IF NOT student_verified THEN
    RAISE EXCEPTION 'Student not in specified school';
  END IF;
  
  -- Update status to removed (preserves all data)
  RETURN QUERY
  UPDATE activity_responses
  SET 
    status = 'removed',
    updated_at = NOW()
  WHERE activity_responses.student_email = p_student_email
    AND activity_responses.activity_id = p_activity_id
    AND activity_responses.cycle_number = p_cycle_number
  RETURNING 
    activity_responses.id,
    activity_responses.student_email,
    activity_responses.activity_id,
    activity_responses.status,
    activity_responses.updated_at;
END;
$$;

-- Test the corrected RPC
SELECT * FROM remove_activity_from_student(
  'aramsey@vespa.academy',
  (SELECT id FROM activities WHERE name = 'Types of Attention' LIMIT 1),
  1,
  'tut7@vespa.academy',
  'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
);

-- Should return the updated row with status='removed'

-- Verify count decreased
SELECT COUNT(*) as active_count
FROM get_student_activity_responses(
  'aramsey@vespa.academy',
  'tut7@vespa.academy',
  'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
);
-- Should be 61 now (was 62)

