-- CREATE RPC function to remove activity (bypasses RLS)
-- This allows staff to remove activities from students

CREATE OR REPLACE FUNCTION remove_activity_from_student(
  p_student_email TEXT,
  p_activity_id UUID,
  p_cycle_number INT,
  p_staff_email TEXT,
  p_school_id UUID
)
RETURNS TABLE (
  id UUID,
  student_email TEXT,
  activity_id UUID,
  status TEXT,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER  -- Runs with elevated privileges
AS $$
DECLARE
  staff_account_id_var UUID;
  student_in_school BOOLEAN;
BEGIN
  -- Verify staff member exists and is in the school
  SELECT vs.account_id INTO staff_account_id_var
  FROM vespa_staff vs
  WHERE vs.email = p_staff_email 
  AND vs.school_id = p_school_id;
  
  IF staff_account_id_var IS NULL THEN
    RAISE EXCEPTION 'Staff member not found or not in specified school';
  END IF;
  
  -- Verify student is in the same school
  SELECT EXISTS(
    SELECT 1 FROM vespa_students
    WHERE email = p_student_email
    AND school_id = p_school_id
  ) INTO student_in_school;
  
  IF NOT student_in_school THEN
    RAISE EXCEPTION 'Student not found or not in specified school';
  END IF;
  
  -- Update activity_responses status to 'removed'
  UPDATE activity_responses
  SET 
    status = 'removed',
    updated_at = NOW()
  WHERE activity_responses.student_email = p_student_email
    AND activity_responses.activity_id = p_activity_id
    AND activity_responses.cycle_number = p_cycle_number;
  
  -- Log the removal action
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
    'removed',
    'staff',
    p_staff_email,
    p_cycle_number,
    jsonb_build_object('school_id', p_school_id)
  );
  
  -- Return the updated record
  RETURN QUERY
  SELECT 
    ar.id,
    ar.student_email,
    ar.activity_id,
    ar.status,
    ar.updated_at
  FROM activity_responses ar
  WHERE ar.student_email = p_student_email
    AND ar.activity_id = p_activity_id
    AND ar.cycle_number = p_cycle_number;
END;
$$;

-- Test the function
SELECT * FROM remove_activity_from_student(
  'aramsey@vespa.academy',
  '49f3cd85-80f6-492b-8bff-142a74c7eb3e',
  1,
  'tut7@vespa.academy',
  'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
);

-- Verify it worked
SELECT status FROM activity_responses 
WHERE student_email = 'aramsey@vespa.academy'
  AND activity_id = '49f3cd85-80f6-492b-8bff-142a74c7eb3e';

