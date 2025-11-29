-- ============================================
-- VESPA Staff Table - Future Implementation
-- ============================================
-- Companion to vespa_students
-- Will be implemented when migrating from Knack auth → Supabase auth
-- For now, staff authentication still uses Knack
-- ============================================

-- ============================================
-- Table: vespa_staff (FUTURE)
-- ============================================
-- Canonical staff registry - mirrors vespa_students structure

CREATE TABLE IF NOT EXISTS vespa_staff (
  -- ==========================================
  -- CORE IDENTIFICATION
  -- ==========================================
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,           -- PRIMARY IDENTIFIER
  
  -- Knack references (Phase 1: Knack auth)
  current_knack_id VARCHAR(50),
  historical_knack_ids TEXT[],
  
  -- ==========================================
  -- FUTURE: SUPABASE AUTH
  -- ==========================================
  supabase_user_id UUID,                        -- References auth.users(id)
  auth_provider VARCHAR(50) DEFAULT 'knack',    -- 'knack' or 'supabase'
  password_reset_required BOOLEAN DEFAULT false,
  last_login_at TIMESTAMP WITH TIME ZONE,
  login_count INTEGER DEFAULT 0,
  
  -- ==========================================
  -- BASIC INFORMATION
  -- ==========================================
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  full_name VARCHAR(255),
  phone_number VARCHAR(50),
  
  -- ==========================================
  -- ROLE & PERMISSIONS
  -- ==========================================
  primary_role VARCHAR(50),                     -- tutor/staff_admin/head_of_year/subject_teacher
  secondary_roles TEXT[],                       -- Additional roles
  permissions JSONB DEFAULT '{}'::jsonb,
  /*
  {
    "can_assign_activities": true,
    "can_give_feedback": true,
    "can_award_certificates": true,
    "can_view_reports": true,
    "can_export_data": false
  }
  */
  
  -- ==========================================
  -- SCHOOL/ESTABLISHMENT CONTEXT
  -- ==========================================
  school_id UUID,                               -- References establishments(id)
  school_name VARCHAR(255),
  trust_name VARCHAR(255),
  department VARCHAR(100),                      -- Maths, English, etc
  
  -- ==========================================
  -- WORKLOAD CONTEXT
  -- ==========================================
  assigned_students_count INTEGER DEFAULT 0,    -- Cached count
  active_academic_year VARCHAR(20),             -- "2025/2026"
  
  -- ==========================================
  -- STATUS & LIFECYCLE
  -- ==========================================
  status VARCHAR(50) DEFAULT 'active',          -- active/inactive/suspended/resigned
  is_active BOOLEAN DEFAULT true,
  employment_start_date DATE,
  employment_end_date DATE,
  
  -- ==========================================
  -- PREFERENCES
  -- ==========================================
  preferences JSONB DEFAULT '{}'::jsonb,
  /*
  {
    "language": "en",
    "notifications_enabled": true,
    "email_notifications": true,
    "dashboard_layout": "default",
    "theme": "light"
  }
  */
  
  -- ==========================================
  -- SYNC & INTEGRATION
  -- ==========================================
  last_synced_from_knack TIMESTAMP WITH TIME ZONE,
  knack_user_attributes JSONB,
  
  -- HR system integration
  hr_employee_id VARCHAR(100),
  
  -- ==========================================
  -- METADATA
  -- ==========================================
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by VARCHAR(50) DEFAULT 'system',
  
  -- Soft delete
  deleted_at TIMESTAMP WITH TIME ZONE,
  deleted_by VARCHAR(255),
  deleted_reason TEXT
);

-- Indexes
CREATE UNIQUE INDEX idx_vespa_staff_email ON vespa_staff(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_vespa_staff_current_knack_id ON vespa_staff(current_knack_id);
CREATE INDEX idx_vespa_staff_supabase_user_id ON vespa_staff(supabase_user_id);
CREATE INDEX idx_vespa_staff_active ON vespa_staff(is_active) WHERE is_active = true AND deleted_at IS NULL;
CREATE INDEX idx_vespa_staff_school ON vespa_staff(school_name);
CREATE INDEX idx_vespa_staff_primary_role ON vespa_staff(primary_role);
CREATE INDEX idx_vespa_staff_status ON vespa_staff(status);


-- ============================================
-- Helper Functions for vespa_staff
-- ============================================

-- Function: Get or create vespa_staff from Knack auth
CREATE OR REPLACE FUNCTION get_or_create_vespa_staff(
  staff_email_param VARCHAR,
  knack_attributes JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  staff_record_id UUID;
  knack_id_value VARCHAR;
BEGIN
  -- Try to find existing record
  SELECT id INTO staff_record_id
  FROM vespa_staff
  WHERE email = staff_email_param;
  
  IF staff_record_id IS NOT NULL THEN
    UPDATE vespa_staff
    SET last_synced_from_knack = NOW()
    WHERE id = staff_record_id;
    
    RETURN staff_record_id;
  END IF;
  
  -- Create new record
  IF knack_attributes IS NOT NULL THEN
    knack_id_value := knack_attributes->>'id';
  END IF;
  
  INSERT INTO vespa_staff (
    email,
    current_knack_id,
    historical_knack_ids,
    first_name,
    last_name,
    full_name,
    knack_user_attributes,
    last_synced_from_knack,
    auth_provider
  ) VALUES (
    staff_email_param,
    knack_id_value,
    ARRAY[knack_id_value],
    knack_attributes->>'first_name',
    knack_attributes->>'last_name',
    CONCAT_WS(' ', knack_attributes->>'first_name', knack_attributes->>'last_name'),
    knack_attributes,
    NOW(),
    'knack'
  )
  RETURNING id INTO staff_record_id;
  
  RAISE NOTICE 'Created new vespa_staff record: %', staff_email_param;
  
  RETURN staff_record_id;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- RLS Policies for vespa_staff
-- ============================================
ALTER TABLE vespa_staff ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff can read own record" ON vespa_staff FOR SELECT 
USING (email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Staff can update own record" ON vespa_staff FOR UPDATE 
USING (email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Service role full access on vespa_staff" ON vespa_staff FOR ALL TO service_role USING (true);


-- ============================================
-- MIGRATION PATH NOTES
-- ============================================

/*

PHASE 1: Current State (Knack Auth)
- vespa_students: Created ✅
- vespa_staff: Created ✅
- Auth: Still uses Knack.getUserAttributes() ✅
- Activities: Uses vespa_students ✅
- Questionnaire/Reports: Uses legacy 'students' table ✅

PHASE 2: Dual Auth (Gradual Migration)
- New students: Create directly in vespa_students with Supabase auth
- Existing students: Still use Knack auth, auto-sync to vespa_students
- Vue apps check: Knack auth first, fallback to Supabase
- Backend API handles both auth methods

PHASE 3: Supabase Auth Only
- All auth moved to Supabase Auth (auth.users)
- vespa_students.supabase_user_id populated
- vespa_staff.supabase_user_id populated
- Knack becomes read-only archive
- vespa_students = THE student registry
- vespa_staff = THE staff registry

PHASE 4: Complete Migration
- Questionnaire/Reports migrated to use vespa_students
- Legacy 'students' table archived or dropped
- All systems use vespa_students/vespa_staff
- Complete independence from Knack ✅

*/


-- ============================================
-- SUCCESS MESSAGE
-- ============================================
SELECT '✅ vespa_staff Table Created!' as status;
SELECT '👥 Mirrors vespa_students structure' as note;
SELECT '🔄 Ready for future Supabase auth migration' as note;

