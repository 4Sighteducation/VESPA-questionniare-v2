/**
 * RLS POLICIES FOR EMULATION SUPPORT
 * 
 * These policies enable super users to emulate different schools while maintaining
 * proper access control and data isolation for regular staff admins and students.
 * 
 * Date: November 27, 2025
 * Version: 1.0
 */

-- ============================================================================
-- HELPER FUNCTION: Set Emulation Context
-- ============================================================================

/**
 * Set emulation context for a session
 * Super users call this before querying to emulate a specific school
 */
CREATE OR REPLACE FUNCTION set_emulation_context(emulated_school_id_param UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Set the emulation context for this session
  PERFORM set_config('app.emulated_school_id', emulated_school_id_param::text, false);
END;
$$;

/**
 * Clear emulation context for a session
 */
CREATE OR REPLACE FUNCTION clear_emulation_context()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Clear the emulation context
  PERFORM set_config('app.emulated_school_id', '', false);
END;
$$;

/**
 * Get current emulation context
 */
CREATE OR REPLACE FUNCTION get_emulation_context()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  emulated_id TEXT;
BEGIN
  emulated_id := current_setting('app.emulated_school_id', true);
  IF emulated_id IS NULL OR emulated_id = '' THEN
    RETURN NULL;
  END IF;
  RETURN emulated_id::UUID;
END;
$$;

-- ============================================================================
-- HELPER FUNCTION: Get Current User Email from JWT
-- ============================================================================

/**
 * Extract email from JWT claims
 * For use in RLS policies
 */
CREATE OR REPLACE FUNCTION current_user_email()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN current_setting('request.jwt.claims', true)::json->>'email';
END;
$$;

-- ============================================================================
-- HELPER FUNCTION: Check if User is Super User
-- ============================================================================

/**
 * Check if the current user has super_user role
 */
CREATE OR REPLACE FUNCTION is_super_user()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM vespa_staff s
    JOIN user_roles r ON s.account_id = r.account_id
    WHERE s.email = current_user_email()
    AND r.role_type = 'super_user'
  );
END;
$$;

-- ============================================================================
-- RLS POLICIES: vespa_students
-- ============================================================================

-- DROP EXISTING POLICIES (if any)
DROP POLICY IF EXISTS "students_own_data" ON vespa_students;
DROP POLICY IF EXISTS "super_user_all_schools" ON vespa_students;
DROP POLICY IF EXISTS "super_user_emulated_school" ON vespa_students;
DROP POLICY IF EXISTS "staff_admin_own_school" ON vespa_students;
DROP POLICY IF EXISTS "tutor_connected_students" ON vespa_students;
DROP POLICY IF EXISTS "head_of_year_connected_students" ON vespa_students;
DROP POLICY IF EXISTS "subject_teacher_connected_students" ON vespa_students;

-- Enable RLS on vespa_students
ALTER TABLE vespa_students ENABLE ROW LEVEL SECURITY;

/**
 * POLICY 1: Students see only their own data
 */
CREATE POLICY "students_own_data"
ON vespa_students
FOR ALL
TO authenticated
USING (email = current_user_email());

/**
 * POLICY 2: Super Users see ALL schools when NOT emulating
 */
CREATE POLICY "super_user_all_schools"
ON vespa_students
FOR ALL
TO authenticated
USING (
  is_super_user() 
  AND get_emulation_context() IS NULL
);

/**
 * POLICY 3: Super Users see ONLY emulated school when emulating
 */
CREATE POLICY "super_user_emulated_school"
ON vespa_students
FOR ALL
TO authenticated
USING (
  is_super_user()
  AND school_id = get_emulation_context()
);

/**
 * POLICY 4: Staff Admins see only their school's students
 */
CREATE POLICY "staff_admin_own_school"
ON vespa_students
FOR ALL
TO authenticated
USING (
  school_id IN (
    SELECT s.school_id
    FROM vespa_staff s
    JOIN user_roles r ON s.account_id = r.account_id
    WHERE s.email = current_user_email()
    AND r.role_type = 'staff_admin'
  )
);

/**
 * POLICY 5: Tutors see only their connected students
 */
CREATE POLICY "tutor_connected_students"
ON vespa_students
FOR ALL
TO authenticated
USING (
  account_id IN (
    SELECT uc.student_account_id
    FROM user_connections uc
    JOIN vespa_staff s ON uc.staff_account_id = s.account_id
    WHERE s.email = current_user_email()
    AND uc.connection_type = 'tutor'
  )
);

/**
 * POLICY 6: Heads of Year see connected students
 */
CREATE POLICY "head_of_year_connected_students"
ON vespa_students
FOR ALL
TO authenticated
USING (
  account_id IN (
    SELECT uc.student_account_id
    FROM user_connections uc
    JOIN vespa_staff s ON uc.staff_account_id = s.account_id
    WHERE s.email = current_user_email()
    AND uc.connection_type = 'head_of_year'
  )
);

/**
 * POLICY 7: Subject Teachers see connected students
 */
CREATE POLICY "subject_teacher_connected_students"
ON vespa_students
FOR ALL
TO authenticated
USING (
  account_id IN (
    SELECT uc.student_account_id
    FROM user_connections uc
    JOIN vespa_staff s ON uc.staff_account_id = s.account_id
    WHERE s.email = current_user_email()
    AND uc.connection_type = 'subject_teacher'
  )
);

-- ============================================================================
-- RLS POLICIES: vespa_staff
-- ============================================================================

-- DROP EXISTING POLICIES (if any)
DROP POLICY IF EXISTS "staff_own_data" ON vespa_staff;
DROP POLICY IF EXISTS "super_user_all_staff" ON vespa_staff;
DROP POLICY IF EXISTS "super_user_emulated_staff" ON vespa_staff;
DROP POLICY IF EXISTS "staff_admin_own_school_staff" ON vespa_staff;

-- Enable RLS on vespa_staff
ALTER TABLE vespa_staff ENABLE ROW LEVEL SECURITY;

/**
 * POLICY 1: Staff see their own data
 */
CREATE POLICY "staff_own_data"
ON vespa_staff
FOR ALL
TO authenticated
USING (email = current_user_email());

/**
 * POLICY 2: Super Users see ALL staff when NOT emulating
 */
CREATE POLICY "super_user_all_staff"
ON vespa_staff
FOR ALL
TO authenticated
USING (
  is_super_user()
  AND get_emulation_context() IS NULL
);

/**
 * POLICY 3: Super Users see ONLY emulated school staff when emulating
 */
CREATE POLICY "super_user_emulated_staff"
ON vespa_staff
FOR ALL
TO authenticated
USING (
  is_super_user()
  AND school_id = get_emulation_context()
);

/**
 * POLICY 4: Staff Admins see their school's staff
 */
CREATE POLICY "staff_admin_own_school_staff"
ON vespa_staff
FOR ALL
TO authenticated
USING (
  school_id IN (
    SELECT s.school_id
    FROM vespa_staff s
    JOIN user_roles r ON s.account_id = r.account_id
    WHERE s.email = current_user_email()
    AND r.role_type = 'staff_admin'
  )
);

-- ============================================================================
-- RLS POLICIES: user_connections
-- ============================================================================

-- DROP EXISTING POLICIES (if any)
DROP POLICY IF EXISTS "super_user_all_connections" ON user_connections;
DROP POLICY IF EXISTS "super_user_emulated_connections" ON user_connections;
DROP POLICY IF EXISTS "staff_own_connections" ON user_connections;
DROP POLICY IF EXISTS "students_own_connections" ON user_connections;

-- Enable RLS on user_connections
ALTER TABLE user_connections ENABLE ROW LEVEL SECURITY;

/**
 * POLICY 1: Super Users see all connections when NOT emulating
 */
CREATE POLICY "super_user_all_connections"
ON user_connections
FOR ALL
TO authenticated
USING (is_super_user() AND get_emulation_context() IS NULL);

/**
 * POLICY 2: Super Users see only emulated school connections
 */
CREATE POLICY "super_user_emulated_connections"
ON user_connections
FOR ALL
TO authenticated
USING (
  is_super_user()
  AND (
    student_account_id IN (
      SELECT id FROM vespa_accounts 
      WHERE school_id = get_emulation_context()
    )
    OR staff_account_id IN (
      SELECT account_id FROM vespa_staff
      WHERE school_id = get_emulation_context()
    )
  )
);

/**
 * POLICY 3: Staff see their connections
 */
CREATE POLICY "staff_own_connections"
ON user_connections
FOR ALL
TO authenticated
USING (
  staff_account_id IN (
    SELECT account_id FROM vespa_staff
    WHERE email = current_user_email()
  )
);

/**
 * POLICY 4: Students see their connections
 */
CREATE POLICY "students_own_connections"
ON user_connections
FOR ALL
TO authenticated
USING (
  student_account_id IN (
    SELECT id FROM vespa_accounts
    WHERE email = current_user_email()
  )
);

-- ============================================================================
-- RLS POLICIES: user_roles
-- ============================================================================

-- DROP EXISTING POLICIES (if any)
DROP POLICY IF EXISTS "super_user_all_roles" ON user_roles;
DROP POLICY IF EXISTS "super_user_emulated_roles" ON user_roles;
DROP POLICY IF EXISTS "staff_own_roles" ON user_roles;

-- Enable RLS on user_roles
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

/**
 * POLICY 1: Super Users see all roles when NOT emulating
 */
CREATE POLICY "super_user_all_roles"
ON user_roles
FOR ALL
TO authenticated
USING (is_super_user() AND get_emulation_context() IS NULL);

/**
 * POLICY 2: Super Users see only emulated school roles
 */
CREATE POLICY "super_user_emulated_roles"
ON user_roles
FOR ALL
TO authenticated
USING (
  is_super_user()
  AND account_id IN (
    SELECT account_id FROM vespa_staff
    WHERE school_id = get_emulation_context()
  )
);

/**
 * POLICY 3: Staff see their own roles
 */
CREATE POLICY "staff_own_roles"
ON user_roles
FOR ALL
TO authenticated
USING (
  account_id IN (
    SELECT account_id FROM vespa_staff
    WHERE email = current_user_email()
  )
);

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant execute on helper functions to authenticated users
GRANT EXECUTE ON FUNCTION set_emulation_context TO authenticated;
GRANT EXECUTE ON FUNCTION clear_emulation_context TO authenticated;
GRANT EXECUTE ON FUNCTION get_emulation_context TO authenticated;
GRANT EXECUTE ON FUNCTION current_user_email TO authenticated;
GRANT EXECUTE ON FUNCTION is_super_user TO authenticated;

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

/**
 * EXAMPLE 1: Super User Working Without Emulation
 * 
 * -- View all students across all schools
 * SELECT * FROM vespa_students;
 * 
 * -- View all staff across all schools
 * SELECT * FROM vespa_staff;
 */

/**
 * EXAMPLE 2: Super User Emulating a School
 * 
 * -- Set emulation context
 * SELECT set_emulation_context('b4bbffc9-7fb6-415a-9a8a-49648995f6b3'::UUID);
 * 
 * -- Now all queries are scoped to VESPA ACADEMY
 * SELECT * FROM vespa_students; -- Only VESPA ACADEMY students
 * SELECT * FROM vespa_staff;    -- Only VESPA ACADEMY staff
 * 
 * -- Clear emulation when done
 * SELECT clear_emulation_context();
 */

/**
 * EXAMPLE 3: Staff Admin Viewing Their School
 * 
 * -- Staff admin automatically sees only their school
 * SELECT * FROM vespa_students; -- Automatically filtered to their school
 */

/**
 * EXAMPLE 4: Tutor Viewing Connected Students
 * 
 * -- Tutor automatically sees only their students
 * SELECT * FROM vespa_students; -- Automatically filtered to connected students
 */

-- ============================================================================
-- TESTING QUERIES
-- ============================================================================

/**
 * TEST 1: Verify RLS is enabled
 */
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('vespa_students', 'vespa_staff', 'user_connections', 'user_roles');

/**
 * TEST 2: List all policies
 */
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('vespa_students', 'vespa_staff', 'user_connections', 'user_roles')
ORDER BY tablename, policyname;

/**
 * TEST 3: Check if emulation context is set
 */
SELECT get_emulation_context() AS emulated_school_id;

/**
 * TEST 4: Check if current user is super user
 */
SELECT is_super_user() AS is_super_user;

-- ============================================================================
-- MAINTENANCE QUERIES
-- ============================================================================

/**
 * DISABLE RLS (for maintenance - use with caution!)
 */
-- ALTER TABLE vespa_students DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE vespa_staff DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE user_connections DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE user_roles DISABLE ROW LEVEL SECURITY;

/**
 * RE-ENABLE RLS (after maintenance)
 */
-- ALTER TABLE vespa_students ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE vespa_staff ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE user_connections ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

