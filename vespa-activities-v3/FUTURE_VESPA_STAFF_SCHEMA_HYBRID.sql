-- ============================================
-- VESPA Hybrid Account System - Staff & Authentication
-- ============================================
-- Version: 2.0 (Hybrid Approach)
-- Date: November 2025
-- Status: Ready for deployment
--
-- ARCHITECTURE: Hybrid Approach (Best of Both Worlds)
-- - Unified auth layer (vespa_accounts)
-- - Domain-specific extensions (vespa_students, vespa_staff)
-- - Role-based access (user_roles)
-- - UUID-based relationships (user_connections)
-- - Smooth migration path from Knack → Supabase Auth
-- ============================================

-- ============================================
-- PHASE 1: Core Account System
-- ============================================

-- Table: vespa_accounts
-- Purpose: Unified authentication and core identity
-- This is the single source of truth for ALL users (students + staff)
CREATE TABLE IF NOT EXISTS vespa_accounts (
  -- ==========================================
  -- CORE IDENTITY
  -- ==========================================
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,           -- PRIMARY IDENTIFIER
  
  -- ==========================================
  -- AUTHENTICATION BRIDGE
  -- ==========================================
  -- Phase 1 (NOW): supabase_user_id = NULL, auth_provider = 'knack'
  -- Phase 2 (Transition): Both populated during dual-auth
  -- Phase 3 (Future): auth_provider = 'supabase', full Supabase Auth
  supabase_user_id UUID UNIQUE,                 -- Will reference auth.users(id)
  auth_provider VARCHAR(50) DEFAULT 'knack',    -- 'knack' or 'supabase'
  password_reset_required BOOLEAN DEFAULT false,
  last_login_at TIMESTAMP WITH TIME ZONE,
  login_count INTEGER DEFAULT 0,
  
  -- ==========================================
  -- KNACK BRIDGE (Temporary)
  -- ==========================================
  -- Track Knack IDs during migration
  current_knack_id VARCHAR(50),
  historical_knack_ids TEXT[],                  -- For year rollovers
  knack_user_attributes JSONB,                  -- Full Knack user object
  last_synced_from_knack TIMESTAMP WITH TIME ZONE,
  
  -- ==========================================
  -- BASIC INFORMATION
  -- ==========================================
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  full_name VARCHAR(255),
  phone_number VARCHAR(50),
  avatar_url TEXT,
  
  -- ==========================================
  -- ORGANIZATIONAL CONTEXT
  -- ==========================================
  school_id UUID,                               -- Future: references schools(id)
  school_name VARCHAR(255),
  trust_name VARCHAR(255),
  
  -- ==========================================
  -- ACCOUNT STATUS
  -- ==========================================
  account_type VARCHAR(20) NOT NULL,            -- 'student' or 'staff'
  is_active BOOLEAN DEFAULT true,
  status VARCHAR(50) DEFAULT 'active',          -- active/inactive/suspended
  deactivated_at TIMESTAMP WITH TIME ZONE,
  deactivated_reason TEXT,
  
  -- ==========================================
  -- PREFERENCES
  -- ==========================================
  preferences JSONB DEFAULT '{
    "language": "en",
    "notifications_enabled": true,
    "email_notifications": true,
    "theme": "light"
  }'::jsonb,
  
  -- ==========================================
  -- METADATA
  -- ==========================================
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by VARCHAR(50) DEFAULT 'system',
  
  -- Soft delete
  deleted_at TIMESTAMP WITH TIME ZONE,
  deleted_by VARCHAR(255),
  
  CONSTRAINT valid_account_type CHECK (account_type IN ('student', 'staff')),
  CONSTRAINT valid_auth_provider CHECK (auth_provider IN ('knack', 'supabase')),
  CONSTRAINT valid_account_status CHECK (status IN ('active', 'inactive', 'suspended', 'graduated', 'resigned'))
);

-- Indexes for vespa_accounts
CREATE UNIQUE INDEX idx_vespa_accounts_email ON vespa_accounts(email) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX idx_vespa_accounts_supabase_user ON vespa_accounts(supabase_user_id) WHERE supabase_user_id IS NOT NULL;
CREATE INDEX idx_vespa_accounts_knack_id ON vespa_accounts(current_knack_id);
CREATE INDEX idx_vespa_accounts_type ON vespa_accounts(account_type);
CREATE INDEX idx_vespa_accounts_active ON vespa_accounts(is_active) WHERE is_active = true AND deleted_at IS NULL;
CREATE INDEX idx_vespa_accounts_school ON vespa_accounts(school_name);

COMMENT ON TABLE vespa_accounts IS 'Unified account system for all users (students + staff). Single source of truth for authentication and core identity.';


-- ============================================
-- PHASE 2: Domain-Specific Extensions
-- ============================================

-- Table: vespa_staff
-- Purpose: Staff-specific data (extends vespa_accounts)
-- All staff members (tutors, admins, heads of year, etc.)
CREATE TABLE IF NOT EXISTS vespa_staff (
  -- ==========================================
  -- CORE LINKING
  -- ==========================================
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id UUID UNIQUE NOT NULL REFERENCES vespa_accounts(id) ON DELETE CASCADE,
  email VARCHAR(255) UNIQUE NOT NULL,           -- Denormalized for performance
  
  -- ==========================================
  -- EMPLOYMENT INFORMATION
  -- ==========================================
  employee_id VARCHAR(100),
  department VARCHAR(100),                      -- Maths, English, Pastoral, etc.
  position_title VARCHAR(255),                  -- "Head of Year 10", "Lead Tutor", etc.
  employment_start_date DATE,
  employment_end_date DATE,
  
  -- ==========================================
  -- WORKLOAD CONTEXT
  -- ==========================================
  assigned_students_count INTEGER DEFAULT 0,    -- Cached count (updated by trigger)
  active_academic_year VARCHAR(20),             -- "2025/2026"
  max_student_capacity INTEGER,                 -- Optional workload limit
  
  -- ==========================================
  -- ACTIVITY SYSTEM STATS (Cached)
  -- ==========================================
  total_activities_assigned INTEGER DEFAULT 0,
  total_feedback_given INTEGER DEFAULT 0,
  total_certificates_awarded INTEGER DEFAULT 0,
  last_activity_at TIMESTAMP WITH TIME ZONE,
  
  -- ==========================================
  -- METADATA
  -- ==========================================
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for vespa_staff
CREATE UNIQUE INDEX idx_vespa_staff_account_id ON vespa_staff(account_id);
CREATE UNIQUE INDEX idx_vespa_staff_email ON vespa_staff(email);
CREATE INDEX idx_vespa_staff_department ON vespa_staff(department);
CREATE INDEX idx_vespa_staff_academic_year ON vespa_staff(active_academic_year);

COMMENT ON TABLE vespa_staff IS 'Staff-specific data. Extends vespa_accounts with employment and workload information.';


-- ============================================
-- PHASE 3: Role-Based Access Control
-- ============================================

-- Table: user_roles
-- Purpose: Multi-role support (one staff member can have multiple roles)
-- Replaces Knack's multiple-object approach
CREATE TABLE IF NOT EXISTS user_roles (
  -- ==========================================
  -- CORE ROLE DATA
  -- ==========================================
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id UUID NOT NULL REFERENCES vespa_accounts(id) ON DELETE CASCADE,
  role_type VARCHAR(50) NOT NULL,
  
  -- ==========================================
  -- ROLE-SPECIFIC DATA (JSONB for flexibility)
  -- ==========================================
  role_data JSONB DEFAULT '{}'::jsonb,
  /*
  Examples:
  
  Tutor:
  {
    "tutor_group": "10A",
    "max_tutees": 25,
    "meeting_day": "Wednesday",
    "meeting_time": "08:30"
  }
  
  Head of Year:
  {
    "year_group": "Year 10",
    "year_size": 180,
    "pastoral_team": ["Ms. Smith", "Mr. Jones"]
  }
  
  Subject Teacher:
  {
    "subject": "Mathematics",
    "key_stage": "KS4",
    "classes": ["10M1", "10M2", "11M1"]
  }
  
  Staff Admin:
  {
    "admin_level": "full",
    "can_export_data": true,
    "can_manage_users": true
  }
  */
  
  -- ==========================================
  -- ROLE STATUS
  -- ==========================================
  is_primary BOOLEAN DEFAULT false,             -- Primary role for UI defaults
  is_active BOOLEAN DEFAULT true,
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  assigned_by UUID REFERENCES vespa_accounts(id),
  deactivated_at TIMESTAMP WITH TIME ZONE,
  
  -- ==========================================
  -- METADATA
  -- ==========================================
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  CONSTRAINT valid_role_type CHECK (role_type IN (
    'tutor', 
    'staff_admin', 
    'head_of_year', 
    'subject_teacher',
    'mentor',
    'coordinator'
  )),
  CONSTRAINT unique_account_role UNIQUE (account_id, role_type)
);

-- Indexes for user_roles
CREATE INDEX idx_user_roles_account ON user_roles(account_id);
CREATE INDEX idx_user_roles_type ON user_roles(role_type);
CREATE INDEX idx_user_roles_active ON user_roles(account_id, is_active) WHERE is_active = true;
CREATE INDEX idx_user_roles_primary ON user_roles(account_id) WHERE is_primary = true;

COMMENT ON TABLE user_roles IS 'Multi-role support. One account can have multiple roles (tutor + head_of_year). Role-specific data stored in JSONB for flexibility.';


-- ============================================
-- PHASE 4: Staff-Student Relationships
-- ============================================

-- Table: user_connections
-- Purpose: Many-to-many relationships (staff ↔ students)
-- Uses UUIDs for proper foreign keys (better than email strings)
CREATE TABLE IF NOT EXISTS user_connections (
  -- ==========================================
  -- CORE CONNECTION
  -- ==========================================
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  staff_account_id UUID NOT NULL REFERENCES vespa_accounts(id) ON DELETE CASCADE,
  student_account_id UUID NOT NULL REFERENCES vespa_accounts(id) ON DELETE CASCADE,
  connection_type VARCHAR(50) NOT NULL,
  
  -- ==========================================
  -- CONNECTION CONTEXT
  -- ==========================================
  context JSONB DEFAULT '{}'::jsonb,
  /*
  Examples:
  
  Tutor:
  {
    "tutor_group": "10A",
    "meeting_schedule": "Wed 08:30"
  }
  
  Subject Teacher:
  {
    "subject": "Mathematics",
    "class": "10M1",
    "set": 1
  }
  
  Head of Year:
  {
    "year_group": "Year 10",
    "pastoral_priority": "medium"
  }
  */
  
  -- ==========================================
  -- SYNC TRACKING
  -- ==========================================
  synced_from_knack BOOLEAN DEFAULT false,
  knack_connection_ids JSONB,                   -- Track source Knack connection IDs
  last_synced_at TIMESTAMP WITH TIME ZONE,
  
  -- ==========================================
  -- METADATA
  -- ==========================================
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by VARCHAR(50) DEFAULT 'system',
  
  CONSTRAINT valid_connection_type CHECK (connection_type IN (
    'tutor',
    'head_of_year',
    'subject_teacher',
    'staff_admin',
    'mentor'
  )),
  CONSTRAINT unique_staff_student_connection UNIQUE (staff_account_id, student_account_id, connection_type),
  CONSTRAINT different_accounts CHECK (staff_account_id != student_account_id)
);

-- Indexes for user_connections
CREATE INDEX idx_user_connections_staff ON user_connections(staff_account_id);
CREATE INDEX idx_user_connections_student ON user_connections(student_account_id);
CREATE INDEX idx_user_connections_type ON user_connections(connection_type);
CREATE INDEX idx_user_connections_composite ON user_connections(staff_account_id, connection_type);

COMMENT ON TABLE user_connections IS 'Staff-student relationships. Many-to-many with UUID foreign keys. One student can have multiple staff connections (tutor, subject teacher, etc.).';


-- ============================================
-- PHASE 5: Helper Functions
-- ============================================

-- Function: Get or create account from Knack auth
CREATE OR REPLACE FUNCTION get_or_create_account(
  email_param VARCHAR,
  account_type_param VARCHAR,
  knack_attributes JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  account_id_result UUID;
  knack_id_value VARCHAR;
  existing_knack_ids TEXT[];
BEGIN
  -- Validate account type
  IF account_type_param NOT IN ('student', 'staff') THEN
    RAISE EXCEPTION 'Invalid account_type: %. Must be student or staff', account_type_param;
  END IF;
  
  -- Try to find existing account
  SELECT id, historical_knack_ids INTO account_id_result, existing_knack_ids
  FROM vespa_accounts
  WHERE email = email_param
  AND deleted_at IS NULL;
  
  -- If found, update sync timestamp and Knack ID if changed
  IF account_id_result IS NOT NULL THEN
    IF knack_attributes IS NOT NULL THEN
      knack_id_value := knack_attributes->>'id';
      
      -- Check if Knack ID changed (year rollover)
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
        
        RAISE NOTICE 'Updated Knack ID for account: % (new ID: %)', email_param, knack_id_value;
      ELSE
        -- Just update sync timestamp
        UPDATE vespa_accounts
        SET last_synced_from_knack = NOW()
        WHERE id = account_id_result;
      END IF;
    END IF;
    
    RETURN account_id_result;
  END IF;
  
  -- Create new account
  IF knack_attributes IS NOT NULL THEN
    knack_id_value := knack_attributes->>'id';
  END IF;
  
  INSERT INTO vespa_accounts (
    email,
    account_type,
    current_knack_id,
    historical_knack_ids,
    first_name,
    last_name,
    full_name,
    phone_number,
    knack_user_attributes,
    last_synced_from_knack,
    auth_provider
  ) VALUES (
    email_param,
    account_type_param,
    knack_id_value,
    ARRAY[knack_id_value],
    knack_attributes->>'first_name',
    knack_attributes->>'last_name',
    CONCAT_WS(' ', knack_attributes->>'first_name', knack_attributes->>'last_name'),
    knack_attributes->>'phone',
    knack_attributes,
    NOW(),
    'knack'
  )
  RETURNING id INTO account_id_result;
  
  RAISE NOTICE 'Created new account: % (%)', email_param, account_type_param;
  
  RETURN account_id_result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_or_create_account IS 'Get existing account or create new one from Knack auth data. Handles Knack ID changes (year rollover).';


-- Function: Get or create staff member
CREATE OR REPLACE FUNCTION get_or_create_staff(
  email_param VARCHAR,
  knack_attributes JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  account_id_result UUID;
  staff_id_result UUID;
BEGIN
  -- Get or create account
  account_id_result := get_or_create_account(email_param, 'staff', knack_attributes);
  
  -- Check if staff record exists
  SELECT id INTO staff_id_result
  FROM vespa_staff
  WHERE account_id = account_id_result;
  
  -- Create staff record if it doesn't exist
  IF staff_id_result IS NULL THEN
    INSERT INTO vespa_staff (
      account_id,
      email,
      active_academic_year
    ) VALUES (
      account_id_result,
      email_param,
      EXTRACT(YEAR FROM CURRENT_DATE) || '/' || (EXTRACT(YEAR FROM CURRENT_DATE) + 1)
    )
    RETURNING id INTO staff_id_result;
    
    RAISE NOTICE 'Created staff record for: %', email_param;
  END IF;
  
  RETURN staff_id_result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_or_create_staff IS 'Get existing staff or create new one. Automatically creates vespa_accounts entry.';


-- Function: Assign role to staff
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
  -- Get account ID
  SELECT id INTO account_id_result
  FROM vespa_accounts
  WHERE email = email_param AND account_type = 'staff' AND deleted_at IS NULL;
  
  IF account_id_result IS NULL THEN
    RAISE EXCEPTION 'Staff account not found for email: %', email_param;
  END IF;
  
  -- Insert or update role
  INSERT INTO user_roles (
    account_id,
    role_type,
    role_data,
    is_primary
  ) VALUES (
    account_id_result,
    role_type_param,
    role_data_param,
    is_primary_param
  )
  ON CONFLICT (account_id, role_type) 
  DO UPDATE SET
    role_data = role_data_param,
    is_primary = is_primary_param,
    is_active = true,
    updated_at = NOW()
  RETURNING id INTO role_id_result;
  
  RAISE NOTICE 'Assigned role % to %', role_type_param, email_param;
  
  RETURN role_id_result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION assign_staff_role IS 'Assign a role to staff member. Handles upsert (insert or update).';


-- Function: Create staff-student connection
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
  -- Get staff account
  SELECT id INTO staff_account_id
  FROM vespa_accounts
  WHERE email = staff_email_param AND account_type = 'staff' AND deleted_at IS NULL;
  
  IF staff_account_id IS NULL THEN
    RAISE EXCEPTION 'Staff account not found: %', staff_email_param;
  END IF;
  
  -- Get student account
  SELECT id INTO student_account_id
  FROM vespa_accounts
  WHERE email = student_email_param AND account_type = 'student' AND deleted_at IS NULL;
  
  IF student_account_id IS NULL THEN
    RAISE EXCEPTION 'Student account not found: %', student_email_param;
  END IF;
  
  -- Insert or update connection
  INSERT INTO user_connections (
    staff_account_id,
    student_account_id,
    connection_type,
    context
  ) VALUES (
    staff_account_id,
    student_account_id,
    connection_type_param,
    context_param
  )
  ON CONFLICT (staff_account_id, student_account_id, connection_type)
  DO UPDATE SET
    context = context_param,
    updated_at = NOW()
  RETURNING id INTO connection_id_result;
  
  RAISE NOTICE 'Created connection: % (%) → %', 
    staff_email_param, connection_type_param, student_email_param;
  
  RETURN connection_id_result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION create_staff_student_connection IS 'Create staff-student connection. Handles upsert.';


-- Function: Update student counts for staff (cached for performance)
CREATE OR REPLACE FUNCTION update_staff_student_counts()
RETURNS TRIGGER AS $$
BEGIN
  -- Update assigned_students_count in vespa_staff
  UPDATE vespa_staff
  SET 
    assigned_students_count = (
      SELECT COUNT(DISTINCT student_account_id)
      FROM user_connections
      WHERE staff_account_id = (
        SELECT account_id FROM vespa_staff WHERE id = vespa_staff.id
      )
    ),
    updated_at = NOW()
  WHERE account_id IN (
    SELECT DISTINCT staff_account_id FROM user_connections
  );
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update counts
CREATE TRIGGER trigger_update_staff_counts
AFTER INSERT OR DELETE OR UPDATE ON user_connections
FOR EACH STATEMENT
EXECUTE FUNCTION update_staff_student_counts();

COMMENT ON FUNCTION update_staff_student_counts IS 'Automatically update cached student counts for staff. Triggered by user_connections changes.';


-- ============================================
-- PHASE 6: Row Level Security (RLS)
-- ============================================

-- Enable RLS on all tables
ALTER TABLE vespa_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE vespa_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_connections ENABLE ROW LEVEL SECURITY;

-- Accounts: Users can read their own account
CREATE POLICY "users_read_own_account" ON vespa_accounts FOR SELECT 
USING (
  email = current_setting('request.jwt.claims', true)::json->>'email'
  OR
  supabase_user_id = auth.uid()
);

CREATE POLICY "users_update_own_account" ON vespa_accounts FOR UPDATE 
USING (
  email = current_setting('request.jwt.claims', true)::json->>'email'
  OR
  supabase_user_id = auth.uid()
);

-- Staff: Can read own record
CREATE POLICY "staff_read_own_record" ON vespa_staff FOR SELECT 
USING (
  email = current_setting('request.jwt.claims', true)::json->>'email'
);

-- Roles: Users can read their own roles
CREATE POLICY "users_read_own_roles" ON user_roles FOR SELECT 
USING (
  account_id IN (
    SELECT id FROM vespa_accounts 
    WHERE email = current_setting('request.jwt.claims', true)::json->>'email'
  )
);

-- Connections: Staff can read their connections
CREATE POLICY "staff_read_own_connections" ON user_connections FOR SELECT 
USING (
  staff_account_id IN (
    SELECT id FROM vespa_accounts 
    WHERE email = current_setting('request.jwt.claims', true)::json->>'email'
  )
);

-- Service role has full access to everything
CREATE POLICY "service_role_all_vespa_accounts" ON vespa_accounts FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all_vespa_staff" ON vespa_staff FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all_user_roles" ON user_roles FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all_user_connections" ON user_connections FOR ALL TO service_role USING (true);


-- ============================================
-- PHASE 7: Migration Views (Backward Compatibility)
-- ============================================

-- View: Legacy staff_student_connections (for backward compatibility)
-- Maps new user_connections to old structure
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

COMMENT ON VIEW staff_student_connections IS 'Backward compatibility view. Maps new user_connections to old staff_student_connections structure.';


-- ============================================
-- SUCCESS MESSAGE
-- ============================================
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ VESPA Hybrid Account System Created!';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Tables Created:';
  RAISE NOTICE '  - vespa_accounts (unified auth layer)';
  RAISE NOTICE '  - vespa_staff (staff-specific data)';
  RAISE NOTICE '  - user_roles (multi-role support)';
  RAISE NOTICE '  - user_connections (staff ↔ student relationships)';
  RAISE NOTICE '';
  RAISE NOTICE '🔧 Helper Functions:';
  RAISE NOTICE '  - get_or_create_account()';
  RAISE NOTICE '  - get_or_create_staff()';
  RAISE NOTICE '  - assign_staff_role()';
  RAISE NOTICE '  - create_staff_student_connection()';
  RAISE NOTICE '';
  RAISE NOTICE '🔐 Row Level Security: ENABLED';
  RAISE NOTICE '';
  RAISE NOTICE '📚 Next Steps:';
  RAISE NOTICE '  1. Run migration script: 06_migrate_staff_accounts.py';
  RAISE NOTICE '  2. Verify with: SELECT COUNT(*) FROM vespa_accounts WHERE account_type = staff';
  RAISE NOTICE '  3. Update backend API to use new structure';
  RAISE NOTICE '';
  RAISE NOTICE '🎯 Migration Path: Knack → Dual Auth → Supabase Auth';
  RAISE NOTICE '';
END $$;

