-- ============================================
-- ADDITIVE MIGRATION: Existing vespa_students → Hybrid Architecture
-- ============================================
-- Version: 2.0 (Additive - Safe for Existing Data)
-- Date: November 2025
-- Status: Ready for deployment
--
-- WHAT THIS DOES:
-- 1. Creates NEW tables (vespa_accounts, vespa_staff, user_roles, user_connections)
-- 2. Migrates existing vespa_students data → vespa_accounts
-- 3. Adds account_id column to vespa_students
-- 4. Links them with foreign keys
-- 5. Preserves ALL existing data
--
-- SAFE TO RUN: Does NOT drop or modify existing data
-- ============================================

BEGIN;

-- ============================================
-- STEP 1: Create vespa_accounts (Parent Table)
-- ============================================

CREATE TABLE IF NOT EXISTS vespa_accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,
  
  -- Auth bridge
  supabase_user_id UUID UNIQUE,
  auth_provider VARCHAR(50) DEFAULT 'knack',
  password_reset_required BOOLEAN DEFAULT false,
  last_login_at TIMESTAMP WITH TIME ZONE,
  login_count INTEGER DEFAULT 0,
  
  -- Knack bridge
  current_knack_id VARCHAR(50),
  historical_knack_ids TEXT[],
  knack_user_attributes JSONB,
  last_synced_from_knack TIMESTAMP WITH TIME ZONE,
  
  -- Basic info
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  full_name VARCHAR(255),
  phone_number VARCHAR(50),
  avatar_url TEXT,
  
  -- Organization (links to existing establishments table)
  school_id UUID REFERENCES establishments(id) ON DELETE SET NULL,
  school_name VARCHAR(255),  -- Denormalized for performance
  trust_name VARCHAR(255),
  
  -- Account type and status
  account_type VARCHAR(20) NOT NULL,
  is_active BOOLEAN DEFAULT true,
  status VARCHAR(50) DEFAULT 'active',
  deactivated_at TIMESTAMP WITH TIME ZONE,
  deactivated_reason TEXT,
  
  -- Preferences
  preferences JSONB DEFAULT '{"language": "en", "notifications_enabled": true, "email_notifications": true, "theme": "light"}'::jsonb,
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by VARCHAR(50) DEFAULT 'system',
  deleted_at TIMESTAMP WITH TIME ZONE,
  deleted_by VARCHAR(255),
  
  CONSTRAINT valid_account_type CHECK (account_type IN ('student', 'staff')),
  CONSTRAINT valid_auth_provider CHECK (auth_provider IN ('knack', 'supabase')),
  CONSTRAINT valid_account_status CHECK (status IN ('active', 'inactive', 'suspended', 'graduated', 'resigned'))
);

-- Indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_vespa_accounts_email ON vespa_accounts(email) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_vespa_accounts_supabase_user ON vespa_accounts(supabase_user_id) WHERE supabase_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_vespa_accounts_knack_id ON vespa_accounts(current_knack_id);
CREATE INDEX IF NOT EXISTS idx_vespa_accounts_type ON vespa_accounts(account_type);
CREATE INDEX IF NOT EXISTS idx_vespa_accounts_active ON vespa_accounts(is_active) WHERE is_active = true AND deleted_at IS NULL;

-- Step 1 complete (vespa_accounts created)


-- ============================================
-- STEP 2: Migrate Existing Students → Accounts
-- ============================================

INSERT INTO vespa_accounts (
  email,
  account_type,
  current_knack_id,
  historical_knack_ids,
  first_name,
  last_name,
  full_name,
  phone_number,
  school_id,
  school_name,
  trust_name,
  is_active,
  status,
  preferences,
  knack_user_attributes,
  last_synced_from_knack,
  created_at,
  updated_at,
  created_by
)
SELECT 
  vs.email,
  'student' as account_type,
  vs.current_knack_id,
  vs.historical_knack_ids,
  vs.first_name,
  vs.last_name,
  vs.full_name,
  vs.phone_number,
  s.establishment_id as school_id,  -- Pull from legacy students table
  vs.school_name,
  vs.trust_name,
  vs.is_active,
  vs.status,
  vs.preferences,
  vs.knack_user_attributes,
  vs.last_synced_from_knack,
  vs.created_at,
  vs.updated_at,
  vs.created_by
FROM vespa_students vs
LEFT JOIN students s ON vs.email = s.email  -- Join to get establishment_id
ON CONFLICT (email) DO NOTHING;

-- Step 2 complete (existing students migrated to vespa_accounts)


-- ============================================
-- STEP 3: Add account_id to vespa_students
-- ============================================

-- Add column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vespa_students' AND column_name = 'account_id'
  ) THEN
    ALTER TABLE vespa_students ADD COLUMN account_id UUID;
  END IF;
END $$;

-- Step 3a complete (account_id column added to vespa_students)

-- Populate account_id by matching emails
UPDATE vespa_students vs
SET account_id = va.id
FROM vespa_accounts va
WHERE vs.email = va.email
AND vs.account_id IS NULL;

-- Step 3b complete (students linked to accounts)


-- ============================================
-- STEP 4: Add Foreign Key (After Data is Linked)
-- ============================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_name = 'vespa_students' 
    AND constraint_name = 'fk_vespa_students_account_id'
  ) THEN
    ALTER TABLE vespa_students 
    ADD CONSTRAINT fk_vespa_students_account_id 
    FOREIGN KEY (account_id) REFERENCES vespa_accounts(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Step 4 complete (foreign key constraint added)


-- ============================================
-- STEP 5: Create vespa_staff Table
-- ============================================

-- Verify vespa_accounts exists before creating vespa_staff
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vespa_accounts') THEN
    RAISE EXCEPTION 'vespa_accounts table must exist before creating vespa_staff';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS vespa_staff (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id UUID UNIQUE NOT NULL REFERENCES vespa_accounts(id) ON DELETE CASCADE,
  email VARCHAR(255) UNIQUE NOT NULL,
  
  -- Employment
  employee_id VARCHAR(100),
  department VARCHAR(100),
  position_title VARCHAR(255),
  employment_start_date DATE,
  employment_end_date DATE,
  
  -- Workload
  assigned_students_count INTEGER DEFAULT 0,
  active_academic_year VARCHAR(20),
  max_student_capacity INTEGER,
  
  -- Activity stats (cached)
  total_activities_assigned INTEGER DEFAULT 0,
  total_feedback_given INTEGER DEFAULT 0,
  total_certificates_awarded INTEGER DEFAULT 0,
  last_activity_at TIMESTAMP WITH TIME ZONE,
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_vespa_staff_account_id ON vespa_staff(account_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_vespa_staff_email ON vespa_staff(email);
CREATE INDEX IF NOT EXISTS idx_vespa_staff_department ON vespa_staff(department);
CREATE INDEX IF NOT EXISTS idx_vespa_staff_academic_year ON vespa_staff(active_academic_year);

-- Step 5 complete (vespa_staff table created)


-- ============================================
-- STEP 6: Create user_roles Table
-- ============================================

CREATE TABLE IF NOT EXISTS user_roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id UUID NOT NULL REFERENCES vespa_accounts(id) ON DELETE CASCADE,
  role_type VARCHAR(50) NOT NULL,
  role_data JSONB DEFAULT '{}'::jsonb,
  is_primary BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  assigned_by UUID REFERENCES vespa_accounts(id),
  deactivated_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  CONSTRAINT valid_role_type CHECK (role_type IN (
    'tutor', 'staff_admin', 'head_of_year', 'subject_teacher', 
    'mentor', 'coordinator', 'general_staff', 'head_of_department', 'parent'
  )),
  CONSTRAINT unique_account_role UNIQUE (account_id, role_type)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_roles_account ON user_roles(account_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_type ON user_roles(role_type);
CREATE INDEX IF NOT EXISTS idx_user_roles_active ON user_roles(account_id, is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_user_roles_primary ON user_roles(account_id) WHERE is_primary = true;

-- Step 6 complete (user_roles table created)


-- ============================================
-- STEP 7: Create user_connections Table
-- ============================================

CREATE TABLE IF NOT EXISTS user_connections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  staff_account_id UUID NOT NULL REFERENCES vespa_accounts(id) ON DELETE CASCADE,
  student_account_id UUID NOT NULL REFERENCES vespa_accounts(id) ON DELETE CASCADE,
  connection_type VARCHAR(50) NOT NULL,
  context JSONB DEFAULT '{}'::jsonb,
  synced_from_knack BOOLEAN DEFAULT false,
  knack_connection_ids JSONB,
  last_synced_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by VARCHAR(50) DEFAULT 'system',
  
  CONSTRAINT valid_connection_type CHECK (connection_type IN (
    'tutor', 'head_of_year', 'subject_teacher', 'staff_admin', 
    'mentor', 'general_staff', 'head_of_department'
  )),
  CONSTRAINT unique_staff_student_connection UNIQUE (staff_account_id, student_account_id, connection_type),
  CONSTRAINT different_accounts CHECK (staff_account_id != student_account_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_connections_staff ON user_connections(staff_account_id);
CREATE INDEX IF NOT EXISTS idx_user_connections_student ON user_connections(student_account_id);
CREATE INDEX IF NOT EXISTS idx_user_connections_type ON user_connections(connection_type);
CREATE INDEX IF NOT EXISTS idx_user_connections_composite ON user_connections(staff_account_id, connection_type);

-- Step 7 complete (user_connections table created)


-- ============================================
-- STEP 8: Create Helper Functions
-- ============================================

CREATE OR REPLACE FUNCTION get_or_create_account(
  email_param VARCHAR,
  account_type_param VARCHAR,
  knack_attributes JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  account_id_result UUID;
  knack_id_value VARCHAR;
BEGIN
  IF account_type_param NOT IN ('student', 'staff') THEN
    RAISE EXCEPTION 'Invalid account_type: %. Must be student or staff', account_type_param;
  END IF;
  
  SELECT id INTO account_id_result
  FROM vespa_accounts
  WHERE email = email_param AND deleted_at IS NULL;
  
  IF account_id_result IS NOT NULL THEN
    IF knack_attributes IS NOT NULL THEN
      knack_id_value := knack_attributes->>'id';
      
      IF knack_id_value IS NOT NULL AND knack_id_value != (
        SELECT current_knack_id FROM vespa_accounts WHERE id = account_id_result
      ) THEN
        UPDATE vespa_accounts
        SET 
          current_knack_id = knack_id_value,
          historical_knack_ids = array_append(
            COALESCE(historical_knack_ids, ARRAY[]::TEXT[]), 
            knack_id_value
          ),
          knack_user_attributes = knack_attributes,
          last_synced_from_knack = NOW(),
          updated_at = NOW()
        WHERE id = account_id_result;
      ELSE
        UPDATE vespa_accounts SET last_synced_from_knack = NOW() WHERE id = account_id_result;
      END IF;
    END IF;
    RETURN account_id_result;
  END IF;
  
  IF knack_attributes IS NOT NULL THEN
    knack_id_value := knack_attributes->>'id';
  END IF;
  
  INSERT INTO vespa_accounts (
    email, account_type, current_knack_id, historical_knack_ids,
    first_name, last_name, full_name, phone_number,
    knack_user_attributes, last_synced_from_knack, auth_provider
  ) VALUES (
    email_param, account_type_param, knack_id_value, ARRAY[knack_id_value],
    knack_attributes->>'first_name', knack_attributes->>'last_name',
    CONCAT_WS(' ', knack_attributes->>'first_name', knack_attributes->>'last_name'),
    knack_attributes->>'phone', knack_attributes, NOW(), 'knack'
  )
  RETURNING id INTO account_id_result;
  
  RETURN account_id_result;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_or_create_staff(
  email_param VARCHAR,
  knack_attributes JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  account_id_result UUID;
  staff_id_result UUID;
BEGIN
  account_id_result := get_or_create_account(email_param, 'staff', knack_attributes);
  
  SELECT id INTO staff_id_result FROM vespa_staff WHERE account_id = account_id_result;
  
  IF staff_id_result IS NULL THEN
    INSERT INTO vespa_staff (account_id, email, active_academic_year)
    VALUES (
      account_id_result, email_param,
      EXTRACT(YEAR FROM CURRENT_DATE) || '/' || (EXTRACT(YEAR FROM CURRENT_DATE) + 1)
    )
    RETURNING id INTO staff_id_result;
  END IF;
  
  RETURN staff_id_result;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION assign_staff_role(
  email_param VARCHAR,
  role_type_param VARCHAR,
  role_data_param JSONB DEFAULT '{}'::jsonb,
  is_primary_param BOOLEAN DEFAULT false
)
RETURNS UUID AS $$
DECLARE
  account_id_result UUID;
  role_id_result UUID;
BEGIN
  SELECT id INTO account_id_result FROM vespa_accounts 
  WHERE email = email_param AND account_type = 'staff' AND deleted_at IS NULL;
  
  IF account_id_result IS NULL THEN
    RAISE EXCEPTION 'Staff account not found for email: %', email_param;
  END IF;
  
  INSERT INTO user_roles (account_id, role_type, role_data, is_primary)
  VALUES (account_id_result, role_type_param, role_data_param, is_primary_param)
  ON CONFLICT (account_id, role_type) 
  DO UPDATE SET role_data = role_data_param, is_primary = is_primary_param, 
    is_active = true, updated_at = NOW()
  RETURNING id INTO role_id_result;
  
  RETURN role_id_result;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION create_staff_student_connection(
  staff_email_param VARCHAR,
  student_email_param VARCHAR,
  connection_type_param VARCHAR,
  context_param JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
  staff_account_id UUID;
  student_account_id UUID;
  connection_id_result UUID;
BEGIN
  SELECT id INTO staff_account_id FROM vespa_accounts 
  WHERE email = staff_email_param AND account_type = 'staff' AND deleted_at IS NULL;
  
  IF staff_account_id IS NULL THEN
    RAISE EXCEPTION 'Staff account not found: %', staff_email_param;
  END IF;
  
  SELECT id INTO student_account_id FROM vespa_accounts 
  WHERE email = student_email_param AND account_type = 'student' AND deleted_at IS NULL;
  
  IF student_account_id IS NULL THEN
    RAISE EXCEPTION 'Student account not found: %', student_email_param;
  END IF;
  
  INSERT INTO user_connections (staff_account_id, student_account_id, connection_type, context)
  VALUES (staff_account_id, student_account_id, connection_type_param, context_param)
  ON CONFLICT (staff_account_id, student_account_id, connection_type)
  DO UPDATE SET context = context_param, updated_at = NOW()
  RETURNING id INTO connection_id_result;
  
  RETURN connection_id_result;
END;
$$ LANGUAGE plpgsql;


-- Trigger to update staff student counts
CREATE OR REPLACE FUNCTION update_staff_student_counts()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE vespa_staff
  SET assigned_students_count = (
    SELECT COUNT(DISTINCT student_account_id)
    FROM user_connections
    WHERE staff_account_id = vespa_staff.account_id
  ),
  updated_at = NOW()
  WHERE account_id IN (
    SELECT DISTINCT staff_account_id FROM user_connections
  );
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_staff_counts ON user_connections;
CREATE TRIGGER trigger_update_staff_counts
AFTER INSERT OR DELETE OR UPDATE ON user_connections
FOR EACH STATEMENT
EXECUTE FUNCTION update_staff_student_counts();

-- Step 8 complete (helper functions and triggers created)


-- ============================================
-- STEP 9: Row Level Security (RLS)
-- ============================================

ALTER TABLE vespa_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE vespa_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_connections ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "users_read_own_account" ON vespa_accounts;
DROP POLICY IF EXISTS "users_update_own_account" ON vespa_accounts;
DROP POLICY IF EXISTS "staff_read_own_record" ON vespa_staff;
DROP POLICY IF EXISTS "users_read_own_roles" ON user_roles;
DROP POLICY IF EXISTS "staff_read_own_connections" ON user_connections;
DROP POLICY IF EXISTS "service_role_all_vespa_accounts" ON vespa_accounts;
DROP POLICY IF EXISTS "service_role_all_vespa_staff" ON vespa_staff;
DROP POLICY IF EXISTS "service_role_all_user_roles" ON user_roles;
DROP POLICY IF EXISTS "service_role_all_user_connections" ON user_connections;

-- Create policies
CREATE POLICY "users_read_own_account" ON vespa_accounts FOR SELECT 
USING (email = current_setting('request.jwt.claims', true)::json->>'email' OR supabase_user_id = auth.uid());

CREATE POLICY "users_update_own_account" ON vespa_accounts FOR UPDATE 
USING (email = current_setting('request.jwt.claims', true)::json->>'email' OR supabase_user_id = auth.uid());

CREATE POLICY "staff_read_own_record" ON vespa_staff FOR SELECT 
USING (email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "users_read_own_roles" ON user_roles FOR SELECT 
USING (account_id IN (SELECT id FROM vespa_accounts WHERE email = current_setting('request.jwt.claims', true)::json->>'email'));

CREATE POLICY "staff_read_own_connections" ON user_connections FOR SELECT 
USING (staff_account_id IN (SELECT id FROM vespa_accounts WHERE email = current_setting('request.jwt.claims', true)::json->>'email'));

CREATE POLICY "service_role_all_vespa_accounts" ON vespa_accounts FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all_vespa_staff" ON vespa_staff FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all_user_roles" ON user_roles FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all_user_connections" ON user_connections FOR ALL TO service_role USING (true);

-- Step 9 complete (Row Level Security enabled)


-- ============================================
-- STEP 10: Backward Compatibility View
-- ============================================

CREATE OR REPLACE VIEW staff_student_connections AS
SELECT 
  uc.id,
  sa_staff.email as staff_email,
  sa_student.email as student_email,
  uc.connection_type as staff_role,
  uc.synced_from_knack,
  uc.last_synced_at,
  uc.created_at
FROM user_connections uc
JOIN vespa_accounts sa_staff ON uc.staff_account_id = sa_staff.id
JOIN vespa_accounts sa_student ON uc.student_account_id = sa_student.id;

-- Step 10 complete (backward compatibility view created)


-- ============================================
-- SUCCESS MESSAGE
-- ============================================

DO $$
DECLARE
  student_count INTEGER;
  account_count INTEGER;
  linked_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO student_count FROM vespa_students;
  SELECT COUNT(*) INTO account_count FROM vespa_accounts WHERE account_type = 'student';
  SELECT COUNT(*) INTO linked_count FROM vespa_students WHERE account_id IS NOT NULL;
  
  RAISE NOTICE '';
  RAISE NOTICE '═══════════════════════════════════════════════════════';
  RAISE NOTICE '✅ ADDITIVE MIGRATION COMPLETE!';
  RAISE NOTICE '═══════════════════════════════════════════════════════';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Migration Summary:';
  RAISE NOTICE '  • vespa_students: % records', student_count;
  RAISE NOTICE '  • vespa_accounts (students): % records', account_count;
  RAISE NOTICE '  • Linked successfully: % records', linked_count;
  RAISE NOTICE '';
  RAISE NOTICE '📚 New Tables Created:';
  RAISE NOTICE '  ✅ vespa_accounts (unified auth)';
  RAISE NOTICE '  ✅ vespa_staff (staff-specific)';
  RAISE NOTICE '  ✅ user_roles (multi-role support)';
  RAISE NOTICE '  ✅ user_connections (relationships)';
  RAISE NOTICE '';
  RAISE NOTICE '🔧 Helper Functions:';
  RAISE NOTICE '  ✅ get_or_create_account()';
  RAISE NOTICE '  ✅ get_or_create_staff()';
  RAISE NOTICE '  ✅ assign_staff_role()';
  RAISE NOTICE '  ✅ create_staff_student_connection()';
  RAISE NOTICE '';
  RAISE NOTICE '🔐 Row Level Security: ENABLED';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Next Steps:';
  RAISE NOTICE '  1. Run: 06_migrate_staff_accounts.py';
  RAISE NOTICE '  2. Verify: SELECT * FROM vespa_accounts WHERE account_type = ''staff'';';
  RAISE NOTICE '  3. Test: Backend API with new structure';
  RAISE NOTICE '';
  RAISE NOTICE '═══════════════════════════════════════════════════════';
END $$;

COMMIT;

