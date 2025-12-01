-- Create RPC function for saving feedback (bypasses RLS)

CREATE OR REPLACE FUNCTION save_staff_feedback(
  p_response_id UUID,
  p_feedback_text TEXT,
  p_staff_email TEXT,
  p_school_id UUID
)
RETURNS TABLE (
  id UUID,
  student_email VARCHAR(255),
  activity_id UUID,
  staff_feedback TEXT,
  staff_feedback_by VARCHAR(255),
  staff_feedback_at TIMESTAMPTZ,
  feedback_read_by_student BOOLEAN,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  staff_verified BOOLEAN;
  student_school_id UUID;
BEGIN
  -- Verify staff is in the school
  SELECT EXISTS(
    SELECT 1 FROM vespa_staff
    WHERE email = p_staff_email AND school_id = p_school_id
  ) INTO staff_verified;
  
  IF NOT staff_verified THEN
    RAISE EXCEPTION 'Staff not authorized for this school';
  END IF;
  
  -- Verify student is in the same school
  SELECT vs.school_id INTO student_school_id
  FROM activity_responses ar
  JOIN vespa_students vs ON vs.email = ar.student_email
  WHERE ar.id = p_response_id;
  
  IF student_school_id IS NULL OR student_school_id != p_school_id THEN
    RAISE EXCEPTION 'Activity response not found or student not in specified school';
  END IF;
  
  -- Update feedback
  RETURN QUERY
  UPDATE activity_responses
  SET 
    staff_feedback = p_feedback_text,
    staff_feedback_by = p_staff_email,
    staff_feedback_at = NOW(),
    feedback_read_by_student = false,
    updated_at = NOW()
  WHERE activity_responses.id = p_response_id
  RETURNING 
    activity_responses.id,
    activity_responses.student_email,
    activity_responses.activity_id,
    activity_responses.staff_feedback,
    activity_responses.staff_feedback_by,
    activity_responses.staff_feedback_at,
    activity_responses.feedback_read_by_student,
    activity_responses.updated_at;
END;
$$;

-- Create RPC for permanent deletion
CREATE OR REPLACE FUNCTION delete_activity_permanently(
  p_student_email TEXT,
  p_activity_id UUID,
  p_cycle_number INT,
  p_staff_email TEXT,
  p_school_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  staff_verified BOOLEAN;
  student_verified BOOLEAN;
  rows_deleted INT;
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
  
  -- Log before deletion (for audit)
  INSERT INTO activity_history (
    student_email,
    activity_id,
    action,
    triggered_by,
    triggered_by_email,
    cycle_number,
    metadata
  ) VALUES (
    p_student_email,
    p_activity_id,
    'permanently_deleted',
    'staff',
    p_staff_email,
    p_cycle_number,
    jsonb_build_object('school_id', p_school_id, 'warning', 'All responses destroyed')
  );
  
  -- DELETE the row permanently
  DELETE FROM activity_responses
  WHERE activity_responses.student_email = p_student_email
    AND activity_responses.activity_id = p_activity_id
    AND activity_responses.cycle_number = p_cycle_number;
    
  GET DIAGNOSTICS rows_deleted = ROW_COUNT;
  
  IF rows_deleted = 0 THEN
    RAISE EXCEPTION 'Activity response not found';
  END IF;
  
  RETURN true;
END;
$$;

-- Test feedback RPC (replace with real response ID)
-- SELECT * FROM save_staff_feedback(
--   'response-id-here',
--   'Great work on this activity!',
--   'tut7@vespa.academy',
--   'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
-- );

-- Test delete RPC
-- SELECT delete_activity_permanently(
--   'aramsey@vespa.academy',
--   'activity-id-here',
--   1,
--   'tut7@vespa.academy',
--   'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
-- );

