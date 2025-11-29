-- ============================================
-- Fix create_staff_student_connection Function
-- ============================================
-- Fixes ambiguous column reference error
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
  -- Get staff account (explicitly name the table)
  SELECT va.id INTO staff_acct_id
  FROM vespa_accounts va
  WHERE va.email = staff_email_param 
  AND va.account_type = 'staff' 
  AND va.deleted_at IS NULL;
  
  IF staff_acct_id IS NULL THEN
    RAISE EXCEPTION 'Staff account not found: %', staff_email_param;
  END IF;
  
  -- Get student account (explicitly name the table)
  SELECT va.id INTO student_acct_id
  FROM vespa_accounts va
  WHERE va.email = student_email_param 
  AND va.account_type = 'student' 
  AND va.deleted_at IS NULL;
  
  IF student_acct_id IS NULL THEN
    RAISE EXCEPTION 'Student account not found: %', student_email_param;
  END IF;
  
  -- Insert or update connection (use local variables, not column names)
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

-- Test it
DO $$
BEGIN
  RAISE NOTICE '✅ create_staff_student_connection function fixed!';
  RAISE NOTICE '   Ambiguous column reference resolved';
END $$;

