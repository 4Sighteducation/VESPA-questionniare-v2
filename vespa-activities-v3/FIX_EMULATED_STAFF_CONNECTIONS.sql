-- ============================================
-- Fix Connection Function for Emulated Staff
-- ============================================
-- Allows staff with student profiles (emulated mode)
-- to receive connections as if they were students
-- ============================================

DROP FUNCTION IF EXISTS create_staff_student_connection(VARCHAR, VARCHAR, VARCHAR, JSONB);

CREATE OR REPLACE FUNCTION create_staff_student_connection(
  staff_email_param VARCHAR,
  student_email_param VARCHAR,
  connection_type_param VARCHAR,
  context_param JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
  staff_acct_id UUID;
  student_acct_id UUID;
  connection_id_result UUID;
BEGIN
  -- Get staff account (must be staff type)
  SELECT va.id INTO staff_acct_id
  FROM vespa_accounts va
  WHERE va.email = staff_email_param 
  AND va.account_type = 'staff' 
  AND va.deleted_at IS NULL;
  
  IF staff_acct_id IS NULL THEN
    RAISE EXCEPTION 'Staff account not found: %', staff_email_param;
  END IF;
  
  -- Get student account (can be 'student' OR 'staff' with vespa_students profile)
  -- This handles emulated staff (staff testing student mode)
  SELECT va.id INTO student_acct_id
  FROM vespa_accounts va
  WHERE va.email = student_email_param 
  AND va.deleted_at IS NULL
  AND EXISTS (
    SELECT 1 FROM vespa_students vs WHERE vs.account_id = va.id
  );
  
  IF student_acct_id IS NULL THEN
    RAISE EXCEPTION 'Student account not found (or no student profile): %', student_email_param;
  END IF;
  
  -- Insert or update connection
  INSERT INTO user_connections (
    staff_account_id,
    student_account_id,
    connection_type,
    context
  ) VALUES (
    staff_acct_id,
    student_acct_id,
    connection_type_param,
    context_param
  )
  ON CONFLICT (staff_account_id, student_account_id, connection_type)
  DO UPDATE SET
    context = context_param,
    updated_at = NOW()
  RETURNING id INTO connection_id_result;
  
  RETURN connection_id_result;
END;
$$ LANGUAGE plpgsql;

-- Success
DO $$
BEGIN
  RAISE NOTICE '✅ Connection function updated!';
  RAISE NOTICE '   Now supports emulated staff (staff with student profiles)';
END $$;

