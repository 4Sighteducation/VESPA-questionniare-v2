-- ============================================
-- VESPA Activities V3 - FUTURE-READY Schema
-- ============================================
-- Designed to eventually become THE canonical student registry
-- Migration path from Knack auth → Supabase auth
-- ============================================

-- ============================================
-- Table: activities (unchanged)
-- ============================================
-- Drop all tables in correct order (dependencies first)
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS activity_history CASCADE;
DROP TABLE IF EXISTS staff_student_connections CASCADE;
DROP TABLE IF EXISTS student_achievements CASCADE;
DROP TABLE IF EXISTS student_activities CASCADE;
DROP TABLE IF EXISTS activity_responses CASCADE;
DROP TABLE IF EXISTS activity_questions CASCADE;
DROP TABLE IF EXISTS activities CASCADE;
DROP TABLE IF EXISTS vespa_students CASCADE;
DROP TABLE IF EXISTS vespa_staff CASCADE;  -- In case it was created separately

CREATE TABLE activities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  knack_id VARCHAR(50) UNIQUE NOT NULL,
  name VARCHAR(255) UNIQUE NOT NULL,
  slug VARCHAR(255) UNIQUE,
  
  vespa_category VARCHAR(50) NOT NULL,
  level VARCHAR(20) NOT NULL,
  difficulty INTEGER CHECK (difficulty BETWEEN 0 AND 10),
  time_minutes INTEGER,
  
  score_threshold_min INTEGER,
  score_threshold_max INTEGER,
  
  content JSONB NOT NULL DEFAULT '{}'::jsonb,
  
  do_section_html TEXT,
  think_section_html TEXT,
  learn_section_html TEXT,
  reflect_section_html TEXT,
  
  problem_mappings TEXT[],
  curriculum_tags TEXT[],
  
  color VARCHAR(50),
  display_order INTEGER,
  is_active BOOLEAN DEFAULT true,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by_email VARCHAR(255),
  
  CONSTRAINT valid_activity_category CHECK (vespa_category IN ('Vision', 'Effort', 'Systems', 'Practice', 'Attitude')),
  CONSTRAINT valid_activity_level CHECK (level IN ('Level 2', 'Level 3'))
);

CREATE INDEX idx_activity_library_category ON activities(vespa_category);
CREATE INDEX idx_activity_library_level ON activities(level);
CREATE INDEX idx_activity_library_active ON activities(is_active) WHERE is_active = true;
CREATE INDEX idx_activity_library_thresholds ON activities(score_threshold_min, score_threshold_max);
CREATE INDEX idx_activity_library_problem_mappings ON activities USING GIN (problem_mappings);
CREATE INDEX idx_activity_library_slug ON activities(slug);


-- ============================================
-- Table: activity_questions (unchanged)
-- ============================================
CREATE TABLE activity_questions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  
  question_title TEXT NOT NULL,
  text_above_question TEXT,
  question_type VARCHAR(50) NOT NULL,
  dropdown_options TEXT[],
  
  display_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  answer_required BOOLEAN DEFAULT false,
  show_in_final_questions BOOLEAN DEFAULT false,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  CONSTRAINT valid_activity_question_type CHECK (question_type IN (
    'Short Text', 'Paragraph Text', 'Dropdown', 'Date', 
    'Checkboxes', 'Single Checkbox'
  )),
  CONSTRAINT unique_activity_question_order UNIQUE (activity_id, display_order)
);

CREATE INDEX idx_activity_questions_activity ON activity_questions(activity_id);
CREATE INDEX idx_activity_questions_order ON activity_questions(activity_id, display_order);
CREATE INDEX idx_activity_questions_active ON activity_questions(is_active) WHERE is_active = true;


-- ============================================
-- Table: vespa_students (FUTURE CANONICAL REGISTRY)
-- ============================================
-- This will eventually replace the legacy 'students' table
-- Designed to be the single source of truth for all VESPA systems
-- Pairs with future 'vespa_staff' table

CREATE TABLE vespa_students (
  -- ==========================================
  -- CORE IDENTIFICATION (Phase 1 - Knack Auth)
  -- ==========================================
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,           -- PRIMARY IDENTIFIER (never changes)
  
  -- Knack references (Phase 1: Knack auth)
  current_knack_id VARCHAR(50),                 -- Latest Knack ID (changes on year rollover)
  historical_knack_ids TEXT[],                  -- All previous Knack IDs for this student
  
  -- ==========================================
  -- FUTURE: SUPABASE AUTH (Phase 2)
  -- ==========================================
  -- When migrating from Knack → Supabase Auth:
  supabase_user_id UUID,                        -- References auth.users(id) in Supabase
  auth_provider VARCHAR(50) DEFAULT 'knack',    -- 'knack' or 'supabase' or 'google' etc
  password_reset_required BOOLEAN DEFAULT false,
  last_login_at TIMESTAMP WITH TIME ZONE,
  login_count INTEGER DEFAULT 0,
  
  -- ==========================================
  -- BASIC INFORMATION
  -- ==========================================
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  full_name VARCHAR(255),
  date_of_birth DATE,
  
  -- ==========================================
  -- SCHOOL/ESTABLISHMENT CONTEXT
  -- ==========================================
  school_id UUID,                               -- Future: references establishments(id)
  school_name VARCHAR(255),                     -- Denormalized for performance
  trust_name VARCHAR(255),
  
  -- Current year context (updates annually)
  current_year_group VARCHAR(50),               -- Year 12, Year 13, etc
  current_academic_year VARCHAR(20),            -- "2025/2026"
  student_group VARCHAR(100),                   -- Tutor group
  
  -- ==========================================
  -- ACADEMIC CONTEXT
  -- ==========================================
  current_level VARCHAR(20),                    -- Level 2 (GCSE) or Level 3 (A-Level)
  current_cycle INTEGER DEFAULT 1,              -- Current VESPA cycle (1, 2, or 3)
  enrollment_date DATE,                         -- When they started at school
  expected_graduation_date DATE,
  
  -- ==========================================
  -- VESPA DATA SUMMARY (Cached from vespa_scores)
  -- ==========================================
  latest_vespa_scores JSONB,                    -- Latest scores for quick access
  /*
  {
    "cycle": 3,
    "academic_year": "2025/2026",
    "vision": 7,
    "effort": 8,
    "systems": 6,
    "practice": 7,
    "attitude": 9,
    "overall": 7.4,
    "level": "Level 3",
    "completed_date": "2025-11-10"
  }
  */
  
  -- ==========================================
  -- ACTIVITIES GAMIFICATION (Cached)
  -- ==========================================
  total_points INTEGER DEFAULT 0,
  total_activities_completed INTEGER DEFAULT 0,
  total_achievements INTEGER DEFAULT 0,
  current_streak_days INTEGER DEFAULT 0,
  longest_streak_days INTEGER DEFAULT 0,
  
  -- ==========================================
  -- STATUS & LIFECYCLE
  -- ==========================================
  status VARCHAR(50) DEFAULT 'active',          -- active/graduated/withdrawn/suspended
  is_active BOOLEAN DEFAULT true,
  last_activity_at TIMESTAMP WITH TIME ZONE,
  
  -- Year-to-year tracking
  years_in_system INTEGER DEFAULT 1,            -- How many years they've been enrolled
  previous_academic_years TEXT[],               -- ["2024/2025", "2025/2026"]
  
  -- ==========================================
  -- CONTACT & PREFERENCES
  -- ==========================================
  phone_number VARCHAR(50),
  parent_email VARCHAR(255),
  parent_phone VARCHAR(50),
  
  -- User preferences
  preferences JSONB DEFAULT '{}'::jsonb,
  /*
  {
    "language": "en",
    "notifications_enabled": true,
    "email_notifications": true,
    "theme": "light"
  }
  */
  
  -- ==========================================
  -- SYNC & INTEGRATION
  -- ==========================================
  last_synced_from_knack TIMESTAMP WITH TIME ZONE,
  knack_user_attributes JSONB,                  -- Full Knack user object (for reference)
  
  -- Future integrations
  sis_student_id VARCHAR(100),                  -- School Information System ID
  exam_board_candidate_number VARCHAR(50),
  
  -- ==========================================
  -- METADATA
  -- ==========================================
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by VARCHAR(50) DEFAULT 'system',
  
  -- Soft delete (instead of hard delete for audit trail)
  deleted_at TIMESTAMP WITH TIME ZONE,
  deleted_by VARCHAR(255),
  deleted_reason TEXT
);

-- Indexes
CREATE UNIQUE INDEX idx_vespa_students_email ON vespa_students(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_vespa_students_current_knack_id ON vespa_students(current_knack_id);
CREATE INDEX idx_vespa_students_supabase_user_id ON vespa_students(supabase_user_id);
CREATE INDEX idx_vespa_students_historical_knack_ids ON vespa_students USING GIN (historical_knack_ids);
CREATE INDEX idx_vespa_students_active ON vespa_students(is_active) WHERE is_active = true AND deleted_at IS NULL;
CREATE INDEX idx_vespa_students_school ON vespa_students(school_name);
CREATE INDEX idx_vespa_students_year_group ON vespa_students(current_year_group);
CREATE INDEX idx_vespa_students_academic_year ON vespa_students(current_academic_year);
CREATE INDEX idx_vespa_students_status ON vespa_students(status);


-- ============================================
-- Table: activity_responses
-- ============================================
CREATE TABLE activity_responses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  knack_id VARCHAR(50) UNIQUE,
  
  -- References vespa_students (future canonical table)
  student_email VARCHAR(255) NOT NULL REFERENCES vespa_students(email) ON DELETE CASCADE,
  activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  
  cycle_number INTEGER NOT NULL DEFAULT 1,
  academic_year VARCHAR(20),
  
  responses JSONB NOT NULL DEFAULT '{}'::jsonb,
  responses_text TEXT,
  
  status VARCHAR(50) DEFAULT 'in_progress',
  started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,
  time_spent_minutes INTEGER,
  word_count INTEGER,
  
  staff_feedback TEXT,
  staff_feedback_by VARCHAR(255),
  staff_feedback_at TIMESTAMP WITH TIME ZONE,
  feedback_read_by_student BOOLEAN DEFAULT false,
  feedback_read_at TIMESTAMP WITH TIME ZONE,
  
  selected_via VARCHAR(50) DEFAULT 'student_choice',
  
  year_group VARCHAR(50),
  student_group VARCHAR(100),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  CONSTRAINT valid_activity_response_status CHECK (status IN ('in_progress', 'completed', 'abandoned')),
  CONSTRAINT valid_activity_selected_via CHECK (selected_via IN ('staff_assigned', 'student_choice', 'recommended', 'auto')),
  CONSTRAINT unique_activity_response UNIQUE (student_email, activity_id, cycle_number)
);

CREATE INDEX idx_activity_responses_student ON activity_responses(student_email);
CREATE INDEX idx_activity_responses_activity ON activity_responses(activity_id);
CREATE INDEX idx_activity_responses_status ON activity_responses(status);
CREATE INDEX idx_activity_responses_completed ON activity_responses(completed_at) WHERE completed_at IS NOT NULL;
CREATE INDEX idx_activity_responses_cycle ON activity_responses(cycle_number);


-- ============================================
-- Table: student_activities
-- ============================================
CREATE TABLE student_activities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_email VARCHAR(255) NOT NULL REFERENCES vespa_students(email) ON DELETE CASCADE,
  activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  assigned_by VARCHAR(50) DEFAULT 'auto',
  assigned_reason VARCHAR(100),
  
  status VARCHAR(50) DEFAULT 'assigned',
  removed_at TIMESTAMP WITH TIME ZONE,
  
  cycle_number INTEGER DEFAULT 1,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  CONSTRAINT valid_student_activity_status CHECK (status IN ('assigned', 'started', 'completed', 'removed')),
  CONSTRAINT unique_student_activity UNIQUE (student_email, activity_id, cycle_number)
);

CREATE INDEX idx_student_activities_email ON student_activities(student_email);
CREATE INDEX idx_student_activities_status ON student_activities(status);
CREATE INDEX idx_student_activities_cycle ON student_activities(cycle_number);
CREATE INDEX idx_student_activities_activity ON student_activities(activity_id);


-- ============================================
-- Table: student_achievements
-- ============================================
CREATE TABLE student_achievements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_email VARCHAR(255) NOT NULL REFERENCES vespa_students(email) ON DELETE CASCADE,
  
  achievement_type VARCHAR(50) NOT NULL,
  achievement_name VARCHAR(255) NOT NULL,
  achievement_description TEXT,
  icon_emoji VARCHAR(10) DEFAULT '🏆',
  
  points_value INTEGER DEFAULT 0,
  criteria_met JSONB,
  
  date_earned TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  issued_by_staff VARCHAR(255),
  
  is_pinned BOOLEAN DEFAULT false,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_student_achievements_email ON student_achievements(student_email);
CREATE INDEX idx_student_achievements_type ON student_achievements(achievement_type);
CREATE INDEX idx_student_achievements_date ON student_achievements(date_earned DESC);
CREATE INDEX idx_student_achievements_pinned ON student_achievements(is_pinned) WHERE is_pinned = true;


-- ============================================
-- Table: staff_student_connections
-- ============================================
CREATE TABLE staff_student_connections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  staff_email VARCHAR(255) NOT NULL,
  student_email VARCHAR(255) NOT NULL REFERENCES vespa_students(email) ON DELETE CASCADE,
  staff_role VARCHAR(50) NOT NULL,
  
  synced_from_knack BOOLEAN DEFAULT false,
  last_synced_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  CONSTRAINT valid_activity_staff_role CHECK (staff_role IN ('tutor', 'staff_admin', 'head_of_year', 'subject_teacher')),
  CONSTRAINT unique_activity_staff_student_role UNIQUE (staff_email, student_email, staff_role)
);

CREATE INDEX idx_activity_staff_connections_staff ON staff_student_connections(staff_email);
CREATE INDEX idx_activity_staff_connections_student ON staff_student_connections(student_email);
CREATE INDEX idx_activity_staff_connections_role ON staff_student_connections(staff_role);


-- ============================================
-- Table: notifications
-- ============================================
DROP TABLE IF EXISTS notifications CASCADE;

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipient_email VARCHAR(255) NOT NULL,
  recipient_type VARCHAR(20) NOT NULL,
  
  notification_type VARCHAR(50) NOT NULL,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  action_url TEXT,
  
  related_activity_id UUID REFERENCES activities(id) ON DELETE SET NULL,
  related_response_id UUID REFERENCES activity_responses(id) ON DELETE SET NULL,
  related_achievement_id UUID REFERENCES student_achievements(id) ON DELETE SET NULL,
  
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMP WITH TIME ZONE,
  is_dismissed BOOLEAN DEFAULT false,
  
  priority VARCHAR(20) DEFAULT 'normal',
  expires_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  CONSTRAINT valid_notification_recipient_type CHECK (recipient_type IN ('student', 'staff')),
  CONSTRAINT valid_notification_type CHECK (notification_type IN (
    'feedback_received', 'activity_assigned', 'achievement_earned', 
    'reminder', 'milestone', 'staff_note', 'encouragement'
  )),
  CONSTRAINT valid_notification_priority CHECK (priority IN ('urgent', 'high', 'normal', 'low'))
);

CREATE INDEX idx_notifications_recipient ON notifications(recipient_email, is_read);
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);
CREATE INDEX idx_notifications_type ON notifications(notification_type);
CREATE INDEX idx_notifications_unread ON notifications(recipient_email) WHERE NOT is_read;


-- ============================================
-- Table: activity_history
-- ============================================
CREATE TABLE activity_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_email VARCHAR(255) NOT NULL,
  activity_id UUID REFERENCES activities(id) ON DELETE SET NULL,
  activity_name VARCHAR(255),
  
  action VARCHAR(50) NOT NULL,
  triggered_by VARCHAR(50) DEFAULT 'student',
  triggered_by_email VARCHAR(255),
  
  cycle_number INTEGER,
  academic_year VARCHAR(20),
  
  metadata JSONB DEFAULT '{}'::jsonb,
  
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_activity_history_student ON activity_history(student_email);
CREATE INDEX idx_activity_history_activity ON activity_history(activity_id);
CREATE INDEX idx_activity_history_timestamp ON activity_history(timestamp DESC);
CREATE INDEX idx_activity_history_action ON activity_history(action);


-- ============================================
-- Table: achievement_definitions
-- ============================================
DROP TABLE IF EXISTS achievement_definitions CASCADE;

CREATE TABLE achievement_definitions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  achievement_type VARCHAR(50) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  icon_emoji VARCHAR(10) DEFAULT '🏆',
  points_value INTEGER DEFAULT 0,
  
  criteria JSONB NOT NULL,
  
  is_active BOOLEAN DEFAULT true,
  display_order INTEGER,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_achievement_definitions_type ON achievement_definitions(achievement_type);
CREATE INDEX idx_achievement_definitions_active ON achievement_definitions(is_active) WHERE is_active = true;


-- ============================================
-- MIGRATION BRIDGE FUNCTIONS
-- ============================================
-- These help transition from legacy 'students' table to 'activity_students'

-- Function: Get or create vespa_student from Knack auth
CREATE OR REPLACE FUNCTION get_or_create_vespa_student(
  student_email_param VARCHAR,
  knack_attributes JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  student_record_id UUID;
  knack_id_value VARCHAR;
  existing_knack_ids TEXT[];
BEGIN
  -- Try to find existing record by email
  SELECT id, historical_knack_ids INTO student_record_id, existing_knack_ids
  FROM vespa_students
  WHERE email = student_email_param;
  
  -- If found, check if Knack ID needs updating
  IF student_record_id IS NOT NULL THEN
    -- Extract knack_id from attributes
    IF knack_attributes IS NOT NULL THEN
      knack_id_value := knack_attributes->>'id';
      
      -- If Knack ID changed (year rollover), update it
      IF knack_id_value IS NOT NULL AND knack_id_value != (
        SELECT current_knack_id FROM vespa_students WHERE id = student_record_id
      ) THEN
        UPDATE vespa_students
        SET 
          current_knack_id = knack_id_value,
          historical_knack_ids = array_append(
            COALESCE(historical_knack_ids, ARRAY[]::TEXT[]), 
            knack_id_value
          ),
          knack_user_attributes = knack_attributes,
          last_synced_from_knack = NOW(),
          updated_at = NOW()
        WHERE id = student_record_id;
        
        RAISE NOTICE 'Updated Knack ID for student: % (new ID: %)', student_email_param, knack_id_value;
      ELSE
        -- Just update sync timestamp
        UPDATE vespa_students
        SET last_synced_from_knack = NOW()
        WHERE id = student_record_id;
      END IF;
    END IF;
    
    RETURN student_record_id;
  END IF;
  
  -- If not found, create new record
  IF knack_attributes IS NOT NULL THEN
    knack_id_value := knack_attributes->>'id';
  END IF;
  
  INSERT INTO vespa_students (
    email,
    current_knack_id,
    historical_knack_ids,
    first_name,
    last_name,
    full_name,
    current_level,
    knack_user_attributes,
    last_synced_from_knack,
    auth_provider
  ) VALUES (
    student_email_param,
    knack_id_value,
    ARRAY[knack_id_value],
    knack_attributes->>'first_name',
    knack_attributes->>'last_name',
    CONCAT_WS(' ', knack_attributes->>'first_name', knack_attributes->>'last_name'),
    'Level 2',  -- Default
    knack_attributes,
    NOW(),
    'knack'
  )
  RETURNING id INTO student_record_id;
  
  RAISE NOTICE 'Created new vespa_student record: %', student_email_param;
  
  RETURN student_record_id;
END;
$$ LANGUAGE plpgsql;


-- Function: Sync latest VESPA scores to vespa_students
CREATE OR REPLACE FUNCTION sync_vespa_scores_to_vespa_student(
  student_email_param VARCHAR
)
RETURNS void AS $$
DECLARE
  latest_scores RECORD;
BEGIN
  -- Get latest VESPA scores from vespa_scores table
  SELECT * INTO latest_scores
  FROM vespa_scores
  WHERE student_email = student_email_param
  ORDER BY created_at DESC
  LIMIT 1;
  
  IF FOUND THEN
    -- Update vespa_students with latest scores
    UPDATE vespa_students
    SET 
      latest_vespa_scores = jsonb_build_object(
        'cycle', latest_scores.cycle_number,
        'academic_year', latest_scores.academic_year,
        'vision', latest_scores.vision,
        'effort', latest_scores.effort,
        'systems', latest_scores.systems,
        'practice', latest_scores.practice,
        'attitude', latest_scores.attitude,
        'overall', latest_scores.overall,
        'level', latest_scores.level,
        'completed_date', latest_scores.created_at
      ),
      current_level = latest_scores.level,
      current_cycle = latest_scores.cycle_number,
      current_academic_year = latest_scores.academic_year,
      updated_at = NOW()
    WHERE email = student_email_param;
    
    RAISE NOTICE 'Synced VESPA scores for: %', student_email_param;
  END IF;
END;
$$ LANGUAGE plpgsql;


-- Function: Year rollover handler
CREATE OR REPLACE FUNCTION handle_student_year_rollover(
  student_email_param VARCHAR,
  new_knack_id VARCHAR,
  new_year_group VARCHAR,
  new_academic_year VARCHAR
)
RETURNS void AS $$
BEGIN
  UPDATE vespa_students
  SET 
    current_knack_id = new_knack_id,
    historical_knack_ids = array_append(
      COALESCE(historical_knack_ids, ARRAY[]::TEXT[]), 
      new_knack_id
    ),
    current_year_group = new_year_group,
    current_academic_year = new_academic_year,
    previous_academic_years = array_append(
      COALESCE(previous_academic_years, ARRAY[]::TEXT[]), 
      current_academic_year
    ),
    years_in_system = years_in_system + 1,
    current_cycle = 1,  -- Reset to cycle 1 for new year
    updated_at = NOW()
  WHERE email = student_email_param;
  
  RAISE NOTICE 'Year rollover for %: Year % → %, New Knack ID: %', 
    student_email_param, 
    (SELECT current_year_group FROM vespa_students WHERE email = student_email_param),
    new_year_group,
    new_knack_id;
END;
$$ LANGUAGE plpgsql;


-- Gamification helper functions
CREATE OR REPLACE FUNCTION increment_student_completed_count(student_email_param VARCHAR)
RETURNS void AS $$
BEGIN
  UPDATE vespa_students
  SET 
    total_activities_completed = total_activities_completed + 1,
    last_activity_at = NOW(),
    updated_at = NOW()
  WHERE email = student_email_param;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_student_points(student_email_param VARCHAR, points_param INTEGER)
RETURNS void AS $$
BEGIN
  UPDATE vespa_students
  SET 
    total_points = total_points + points_param,
    updated_at = NOW()
  WHERE email = student_email_param;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION increment_student_achievement_count(student_email_param VARCHAR)
RETURNS void AS $$
BEGIN
  UPDATE vespa_students
  SET 
    total_achievements = total_achievements + 1,
    updated_at = NOW()
  WHERE email = student_email_param;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- FUTURE MIGRATION VIEW (Phase 2)
-- ============================================
-- When ready to migrate questionnaire/reports to use vespa_students,
-- create a VIEW that maps old structure to new

CREATE OR REPLACE VIEW legacy_students_bridge AS
SELECT 
  s.id as legacy_id,
  s.email,
  s.knack_id as legacy_knack_id,
  
  -- Map to vespa_students
  vs.id as vespa_student_id,
  vs.current_knack_id,
  vs.first_name,
  vs.last_name,
  vs.full_name,
  vs.school_name,
  vs.current_year_group,
  vs.current_academic_year,
  vs.is_active,
  
  -- Include both table timestamps
  s.created_at as legacy_created_at,
  vs.created_at as canonical_created_at
  
FROM students s
LEFT JOIN vespa_students vs ON s.email = vs.email
WHERE s.email IS NOT NULL;

-- This VIEW allows legacy systems to query "students" but get data from vespa_students
-- Useful for gradual migration


-- ============================================
-- Row Level Security (RLS) Policies
-- ============================================

ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE vespa_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_student_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievement_definitions ENABLE ROW LEVEL SECURITY;

-- Activities (public read)
CREATE POLICY "Anyone can view active activities" ON activities FOR SELECT USING (is_active = true);
CREATE POLICY "Service role full access on activities" ON activities FOR ALL TO service_role USING (true);

CREATE POLICY "Anyone can view active questions" ON activity_questions FOR SELECT USING (is_active = true);
CREATE POLICY "Service role full access on activity_questions" ON activity_questions FOR ALL TO service_role USING (true);

-- VESPA Students
CREATE POLICY "Students can read own record" ON vespa_students FOR SELECT 
USING (email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Students can update own record" ON vespa_students FOR UPDATE 
USING (email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Service role full access on vespa_students" ON vespa_students FOR ALL TO service_role USING (true);

-- Activity Responses
CREATE POLICY "Students can manage own responses" ON activity_responses FOR ALL 
USING (student_email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Staff can read connected student responses" ON activity_responses FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM staff_student_connections
    WHERE staff_email = current_setting('request.jwt.claims', true)::json->>'email'
    AND student_email = activity_responses.student_email
  )
);

CREATE POLICY "Service role full access on activity_responses" ON activity_responses FOR ALL TO service_role USING (true);

-- Student Activities
CREATE POLICY "Students can manage own activities" ON student_activities FOR ALL 
USING (student_email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Staff can manage connected student activities" ON student_activities FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM staff_student_connections
    WHERE staff_email = current_setting('request.jwt.claims', true)::json->>'email'
    AND student_email = student_activities.student_email
  )
);

CREATE POLICY "Service role full access on student_activities" ON student_activities FOR ALL TO service_role USING (true);

-- Achievements
CREATE POLICY "Students can read own achievements" ON student_achievements FOR SELECT 
USING (student_email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Service role full access on student_achievements" ON student_achievements FOR ALL TO service_role USING (true);

-- Staff Connections
CREATE POLICY "Staff can read own connections" ON staff_student_connections FOR SELECT 
USING (staff_email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Service role full access on staff_student_connections" ON staff_student_connections FOR ALL TO service_role USING (true);

-- Notifications
CREATE POLICY "Users can read own notifications" ON notifications FOR SELECT 
USING (recipient_email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Users can update own notifications" ON notifications FOR UPDATE 
USING (recipient_email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Service role full access on notifications" ON notifications FOR ALL TO service_role USING (true);

-- History
CREATE POLICY "Users can read own history" ON activity_history FOR SELECT 
USING (student_email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Service role full access on activity_history" ON activity_history FOR ALL TO service_role USING (true);

-- Achievement Definitions
CREATE POLICY "Anyone can view active achievement definitions" ON achievement_definitions FOR SELECT USING (is_active = true);
CREATE POLICY "Service role full access on achievement_definitions" ON achievement_definitions FOR ALL TO service_role USING (true);


-- ============================================
-- SUCCESS MESSAGE
-- ============================================
SELECT '✅ VESPA Activities V3 Future-Ready Schema Created!' as status;
SELECT '📊 vespa_students: Clean canonical student registry' as note;
SELECT '👥 Ready for future vespa_staff table (matching structure)' as note;
SELECT '🔄 Designed for eventual Knack → Supabase auth migration' as note;
SELECT '🏗️ Handles year rollovers, historical tracking, multi-year students' as note;

