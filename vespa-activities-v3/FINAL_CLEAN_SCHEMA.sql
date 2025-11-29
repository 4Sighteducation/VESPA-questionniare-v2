-- ============================================
-- VESPA Activities V3 - FINAL CLEAN Schema
-- ============================================
-- Uses SEPARATE student registry for activities
-- Leaves existing students table completely untouched
-- ============================================

-- ============================================
-- Table: activities
-- ============================================
DROP TABLE IF EXISTS activity_questions CASCADE;
DROP TABLE IF EXISTS activity_responses CASCADE;
DROP TABLE IF EXISTS student_activities CASCADE;
DROP TABLE IF EXISTS student_achievements CASCADE;
DROP TABLE IF EXISTS staff_student_connections CASCADE;
DROP TABLE IF EXISTS activity_history CASCADE;
DROP TABLE IF EXISTS activities CASCADE;
DROP TABLE IF EXISTS activity_students CASCADE;  -- Clean slate

CREATE TABLE activities (
  -- Core identification
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  knack_id VARCHAR(50) UNIQUE NOT NULL,
  name VARCHAR(255) UNIQUE NOT NULL,
  slug VARCHAR(255) UNIQUE,
  
  -- Classification
  vespa_category VARCHAR(50) NOT NULL,
  level VARCHAR(20) NOT NULL,
  difficulty INTEGER CHECK (difficulty BETWEEN 0 AND 10),
  time_minutes INTEGER,
  
  -- Scoring thresholds
  score_threshold_min INTEGER,
  score_threshold_max INTEGER,
  
  -- Content (JSONB for flexibility)
  content JSONB NOT NULL DEFAULT '{}'::jsonb,
  
  -- Rich text fields (preserving Knack HTML)
  do_section_html TEXT,
  think_section_html TEXT,
  learn_section_html TEXT,
  reflect_section_html TEXT,
  
  -- Problem mappings for self-selection
  problem_mappings TEXT[],
  curriculum_tags TEXT[],
  
  -- Display
  color VARCHAR(50),
  display_order INTEGER,
  is_active BOOLEAN DEFAULT true,
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by_email VARCHAR(255),
  
  -- Constraints
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
-- Table: activity_questions
-- ============================================
CREATE TABLE activity_questions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  
  -- Question content
  question_title TEXT NOT NULL,
  text_above_question TEXT,
  question_type VARCHAR(50) NOT NULL,
  
  -- Options for dropdown/checkbox questions
  dropdown_options TEXT[],
  
  -- Display & validation
  display_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  answer_required BOOLEAN DEFAULT false,
  show_in_final_questions BOOLEAN DEFAULT false,
  
  -- Metadata
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
-- Table: activity_students (NEW - Canonical Registry)
-- ============================================
-- This is our CLEAN student registry for activities
-- Completely separate from legacy 'students' table
-- ONE record per student email (enforced unique)
-- Syncs basic info from Knack on first access

CREATE TABLE activity_students (
  -- Core identification
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,           -- ENFORCED UNIQUE ✅
  
  -- Knack reference (for auth lookup)
  current_knack_id VARCHAR(50),                 -- Latest Knack ID (may change year-to-year)
  historical_knack_ids TEXT[],                  -- All previous Knack IDs for this student
  
  -- Basic info (synced from Knack)
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  full_name VARCHAR(255),
  
  -- School info
  school_name VARCHAR(255),
  current_year_group VARCHAR(50),               -- Current year (updates each year)
  student_group VARCHAR(100),
  
  -- Academic context
  current_level VARCHAR(20),                    -- Level 2 or Level 3
  current_cycle INTEGER DEFAULT 1,
  current_academic_year VARCHAR(20),            -- e.g., "2025/2026"
  
  -- Status
  is_active BOOLEAN DEFAULT true,
  last_activity_at TIMESTAMP WITH TIME ZONE,
  
  -- Gamification totals (cached for performance)
  total_points INTEGER DEFAULT 0,
  total_activities_completed INTEGER DEFAULT 0,
  total_achievements INTEGER DEFAULT 0,
  
  -- Sync tracking
  last_synced_from_knack TIMESTAMP WITH TIME ZONE,
  knack_user_attributes JSONB,                  -- Store full Knack user object
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_activity_students_email ON activity_students(email);
CREATE INDEX idx_activity_students_knack_id ON activity_students(current_knack_id);
CREATE INDEX idx_activity_students_active ON activity_students(is_active) WHERE is_active = true;
CREATE INDEX idx_activity_students_school ON activity_students(school_name);
CREATE INDEX idx_activity_students_year ON activity_students(current_year_group);


-- ============================================
-- Table: activity_responses
-- ============================================
CREATE TABLE activity_responses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  knack_id VARCHAR(50) UNIQUE,
  
  -- Relationships (uses activity_students, NOT students)
  student_email VARCHAR(255) NOT NULL REFERENCES activity_students(email) ON DELETE CASCADE,
  activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  
  -- Cycle tracking
  cycle_number INTEGER NOT NULL DEFAULT 1,
  academic_year VARCHAR(20),
  
  -- Response data
  responses JSONB NOT NULL DEFAULT '{}'::jsonb,
  responses_text TEXT,
  
  -- Completion tracking
  status VARCHAR(50) DEFAULT 'in_progress',
  started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,
  time_spent_minutes INTEGER,
  word_count INTEGER,
  
  -- Staff feedback
  staff_feedback TEXT,
  staff_feedback_by VARCHAR(255),
  staff_feedback_at TIMESTAMP WITH TIME ZONE,
  feedback_read_by_student BOOLEAN DEFAULT false,
  feedback_read_at TIMESTAMP WITH TIME ZONE,
  
  -- Source tracking
  selected_via VARCHAR(50) DEFAULT 'student_choice',
  
  -- Additional context
  year_group VARCHAR(50),
  student_group VARCHAR(100),
  
  -- Metadata
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
  student_email VARCHAR(255) NOT NULL REFERENCES activity_students(email) ON DELETE CASCADE,
  activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  
  -- Assignment tracking
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  assigned_by VARCHAR(50) DEFAULT 'auto',
  assigned_reason VARCHAR(100),
  
  -- Status
  status VARCHAR(50) DEFAULT 'assigned',
  removed_at TIMESTAMP WITH TIME ZONE,
  
  -- Current cycle context
  cycle_number INTEGER DEFAULT 1,
  
  -- Metadata
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
  student_email VARCHAR(255) NOT NULL REFERENCES activity_students(email) ON DELETE CASCADE,
  
  -- Achievement details
  achievement_type VARCHAR(50) NOT NULL,
  achievement_name VARCHAR(255) NOT NULL,
  achievement_description TEXT,
  icon_emoji VARCHAR(10) DEFAULT '🏆',
  
  -- Points and criteria
  points_value INTEGER DEFAULT 0,
  criteria_met JSONB,
  
  -- Award details
  date_earned TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  issued_by_staff VARCHAR(255),
  
  -- Display
  is_pinned BOOLEAN DEFAULT false,
  
  -- Metadata
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
  student_email VARCHAR(255) NOT NULL REFERENCES activity_students(email) ON DELETE CASCADE,
  staff_role VARCHAR(50) NOT NULL,
  
  -- Sync tracking
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
  
  -- Notification content
  notification_type VARCHAR(50) NOT NULL,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  action_url TEXT,
  
  -- Related entities
  related_activity_id UUID REFERENCES activities(id) ON DELETE SET NULL,
  related_response_id UUID REFERENCES activity_responses(id) ON DELETE SET NULL,
  related_achievement_id UUID REFERENCES student_achievements(id) ON DELETE SET NULL,
  
  -- Status
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMP WITH TIME ZONE,
  is_dismissed BOOLEAN DEFAULT false,
  
  -- Priority
  priority VARCHAR(20) DEFAULT 'normal',
  
  -- Expiry
  expires_at TIMESTAMP WITH TIME ZONE,
  
  -- Metadata
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
  
  -- Action tracking
  action VARCHAR(50) NOT NULL,
  triggered_by VARCHAR(50) DEFAULT 'student',
  triggered_by_email VARCHAR(255),
  
  -- Context
  cycle_number INTEGER,
  academic_year VARCHAR(20),
  
  -- Additional metadata
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
  
  -- Trigger criteria
  criteria JSONB NOT NULL,
  
  is_active BOOLEAN DEFAULT true,
  display_order INTEGER,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_achievement_definitions_type ON achievement_definitions(achievement_type);
CREATE INDEX idx_achievement_definitions_active ON achievement_definitions(is_active) WHERE is_active = true;


-- ============================================
-- Helper Functions
-- ============================================

-- Function: Get or create activity_student record from Knack auth
CREATE OR REPLACE FUNCTION get_or_create_activity_student(
  student_email_param VARCHAR,
  knack_attributes JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  student_record_id UUID;
  knack_id_value VARCHAR;
BEGIN
  -- Try to find existing record
  SELECT id INTO student_record_id
  FROM activity_students
  WHERE email = student_email_param;
  
  -- If found, return it
  IF student_record_id IS NOT NULL THEN
    -- Update last_synced
    UPDATE activity_students
    SET last_synced_from_knack = NOW()
    WHERE id = student_record_id;
    
    RETURN student_record_id;
  END IF;
  
  -- If not found, create new record
  -- Extract knack_id from attributes if provided
  IF knack_attributes IS NOT NULL THEN
    knack_id_value := knack_attributes->>'id';
  END IF;
  
  INSERT INTO activity_students (
    email,
    current_knack_id,
    historical_knack_ids,
    first_name,
    last_name,
    full_name,
    current_level,
    knack_user_attributes,
    last_synced_from_knack
  ) VALUES (
    student_email_param,
    knack_id_value,
    ARRAY[knack_id_value],
    knack_attributes->>'first_name',
    knack_attributes->>'last_name',
    CONCAT(knack_attributes->>'first_name', ' ', knack_attributes->>'last_name'),
    'Level 2',  -- Default, will be updated from VESPA scores
    knack_attributes,
    NOW()
  )
  RETURNING id INTO student_record_id;
  
  RETURN student_record_id;
END;
$$ LANGUAGE plpgsql;


-- Function: Update student when Knack ID changes (year rollover)
CREATE OR REPLACE FUNCTION update_student_knack_id(
  student_email_param VARCHAR,
  new_knack_id VARCHAR
)
RETURNS void AS $$
BEGIN
  UPDATE activity_students
  SET 
    current_knack_id = new_knack_id,
    historical_knack_ids = array_append(
      COALESCE(historical_knack_ids, ARRAY[]::TEXT[]), 
      new_knack_id
    ),
    updated_at = NOW()
  WHERE email = student_email_param;
END;
$$ LANGUAGE plpgsql;


-- Function: Increment student completed count
CREATE OR REPLACE FUNCTION increment_student_completed_count(student_email_param VARCHAR)
RETURNS void AS $$
BEGIN
  UPDATE activity_students
  SET 
    total_activities_completed = total_activities_completed + 1,
    last_activity_at = NOW(),
    updated_at = NOW()
  WHERE email = student_email_param;
END;
$$ LANGUAGE plpgsql;


-- Function: Add points to student
CREATE OR REPLACE FUNCTION add_student_points(student_email_param VARCHAR, points_param INTEGER)
RETURNS void AS $$
BEGIN
  UPDATE activity_students
  SET 
    total_points = total_points + points_param,
    updated_at = NOW()
  WHERE email = student_email_param;
END;
$$ LANGUAGE plpgsql;


-- Function: Increment achievement count
CREATE OR REPLACE FUNCTION increment_student_achievement_count(student_email_param VARCHAR)
RETURNS void AS $$
BEGIN
  UPDATE activity_students
  SET 
    total_achievements = total_achievements + 1,
    updated_at = NOW()
  WHERE email = student_email_param;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- Row Level Security (RLS) Policies
-- ============================================

ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_student_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievement_definitions ENABLE ROW LEVEL SECURITY;

-- Activities & Questions (public read)
CREATE POLICY "Anyone can view active activities" ON activities FOR SELECT USING (is_active = true);
CREATE POLICY "Service role full access on activities" ON activities FOR ALL TO service_role USING (true);

CREATE POLICY "Anyone can view active questions" ON activity_questions FOR SELECT USING (is_active = true);
CREATE POLICY "Service role full access on activity_questions" ON activity_questions FOR ALL TO service_role USING (true);

-- Activity Students
CREATE POLICY "Students can read own record" ON activity_students FOR SELECT 
USING (email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Students can update own record" ON activity_students FOR UPDATE 
USING (email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Service role full access on activity_students" ON activity_students FOR ALL TO service_role USING (true);

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

-- Achievement Definitions (public read)
CREATE POLICY "Anyone can view active achievement definitions" ON achievement_definitions FOR SELECT USING (is_active = true);
CREATE POLICY "Service role full access on achievement_definitions" ON achievement_definitions FOR ALL TO service_role USING (true);


-- ============================================
-- SUCCESS VERIFICATION
-- ============================================

SELECT '✅ VESPA Activities V3 Schema Created Successfully!' as status;

SELECT 'Created activity_students table - Clean canonical student registry' as note;
SELECT 'Legacy students table - Unchanged (used by questionnaire/reports)' as note;
SELECT 'Both systems coexist peacefully via email identifier' as note;


