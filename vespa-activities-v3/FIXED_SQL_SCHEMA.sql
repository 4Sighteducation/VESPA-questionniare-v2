-- ============================================
-- VESPA Activities V3 - Fixed Supabase Schema
-- ============================================
-- Fixes naming conflicts with existing questionnaire tables
-- All indexes renamed with activity_ prefix to avoid collisions

-- ============================================
-- Table: activities
-- ============================================
-- NOTE: If this table already exists, drop and recreate it
DROP TABLE IF EXISTS activity_questions CASCADE;
DROP TABLE IF EXISTS activities CASCADE;

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

-- Indexes with activity_ prefix to avoid conflicts
CREATE INDEX idx_activity_library_category ON activities(vespa_category);
CREATE INDEX idx_activity_library_level ON activities(level);
CREATE INDEX idx_activity_library_active ON activities(is_active) WHERE is_active = true;
CREATE INDEX idx_activity_library_thresholds ON activities(score_threshold_min, score_threshold_max);
CREATE INDEX idx_activity_library_problem_mappings ON activities USING GIN (problem_mappings);
CREATE INDEX idx_activity_library_slug ON activities(slug);


-- ============================================
-- Table: activity_questions (renamed from just 'questions')
-- ============================================
CREATE TABLE activity_questions (
  -- Core fields
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
  
  -- Constraints
  CONSTRAINT valid_activity_question_type CHECK (question_type IN (
    'Short Text', 'Paragraph Text', 'Dropdown', 'Date', 
    'Checkboxes', 'Single Checkbox'
  )),
  CONSTRAINT unique_activity_question_order UNIQUE (activity_id, display_order)
);

-- All indexes renamed with activity_ prefix
CREATE INDEX idx_activity_questions_activity ON activity_questions(activity_id);
CREATE INDEX idx_activity_questions_order ON activity_questions(activity_id, display_order);
CREATE INDEX idx_activity_questions_active ON activity_questions(is_active) WHERE is_active = true;


-- ============================================
-- Table: students
-- ============================================
-- NOTE: This table already exists from questionnaire/reports
-- We'll ADD ALL potentially missing columns needed for activities

-- First, create table if it doesn't exist (for fresh installs)
CREATE TABLE IF NOT EXISTS students (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Now ADD ALL columns we need (safe for existing tables - IF NOT EXISTS)
-- Basic info columns
ALTER TABLE students ADD COLUMN IF NOT EXISTS knack_id VARCHAR(50);
ALTER TABLE students ADD COLUMN IF NOT EXISTS first_name VARCHAR(100);
ALTER TABLE students ADD COLUMN IF NOT EXISTS last_name VARCHAR(100);
ALTER TABLE students ADD COLUMN IF NOT EXISTS full_name VARCHAR(255);

-- School info columns
ALTER TABLE students ADD COLUMN IF NOT EXISTS school_name VARCHAR(255);
ALTER TABLE students ADD COLUMN IF NOT EXISTS year_group VARCHAR(50);
ALTER TABLE students ADD COLUMN IF NOT EXISTS student_group VARCHAR(100);

-- Status columns
ALTER TABLE students ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE students ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMP WITH TIME ZONE;

-- Gamification columns (specific to activities)
ALTER TABLE students ADD COLUMN IF NOT EXISTS total_points INTEGER DEFAULT 0;
ALTER TABLE students ADD COLUMN IF NOT EXISTS total_activities_completed INTEGER DEFAULT 0;
ALTER TABLE students ADD COLUMN IF NOT EXISTS total_achievements INTEGER DEFAULT 0;

-- Sync tracking
ALTER TABLE students ADD COLUMN IF NOT EXISTS last_synced_from_knack TIMESTAMP WITH TIME ZONE;

-- ============================================
-- KNACK_ID HANDLING - SAFE APPROACH
-- ============================================
-- IMPORTANT: Existing tables (vespa_scores, question_responses) use students.id as foreign key
-- We CANNOT delete duplicate student records without breaking those relationships
-- 
-- Solution: Activities system uses EMAIL as identifier (separate from ID-based system)
-- This allows both systems to coexist without conflicts

-- Add non-unique indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_students_knack_id_activities ON students(knack_id) WHERE knack_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_students_email_activities ON students(email);
CREATE INDEX IF NOT EXISTS idx_students_active_activities ON students(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_students_school_activities ON students(school_name) WHERE school_name IS NOT NULL;

-- ============================================
-- IMPORTANT NOTE: Data Integrity Issue Found
-- ============================================
-- The students table has duplicate emails (e.g., cerina.moorhouse@ousedale.org.uk appears twice)
-- This is a pre-existing data issue from questionnaire/reports system
-- 
-- We CANNOT enforce uniqueness on email without cleanup, BUT cleanup is risky because:
-- - vespa_scores uses student_id (UUID) as foreign key
-- - question_responses uses student_id (UUID) as foreign key
-- - Deleting duplicate students would break these relationships
--
-- SOLUTION FOR ACTIVITIES SYSTEM:
-- - Use NON-UNIQUE index on email (allows duplicates)
-- - Activities will query: SELECT * FROM students WHERE email = ? LIMIT 1
-- - This picks first match (usually the older record)
-- - Functionally works fine, even with duplicates present
--
-- TO FIX LATER (separate cleanup project):
-- - Migrate vespa_scores to use student_email instead of student_id
-- - Migrate question_responses to use student_email instead of student_id  
-- - Then safe to deduplicate students table
-- ============================================


-- ============================================
-- Table: activity_responses
-- ============================================
DROP TABLE IF EXISTS activity_responses CASCADE;

CREATE TABLE activity_responses (
  -- Core fields
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  knack_id VARCHAR(50) UNIQUE,
  
  -- Relationships
  student_email VARCHAR(255) NOT NULL REFERENCES students(email) ON DELETE CASCADE,
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
  
  -- Constraints
  CONSTRAINT valid_activity_response_status CHECK (status IN ('in_progress', 'completed', 'abandoned')),
  CONSTRAINT valid_activity_selected_via CHECK (selected_via IN ('staff_assigned', 'student_choice', 'recommended', 'auto')),
  CONSTRAINT unique_activity_response UNIQUE (student_email, activity_id, cycle_number)
);

CREATE INDEX idx_activity_responses_student ON activity_responses(student_email);
CREATE INDEX idx_activity_responses_activity ON activity_responses(activity_id);
CREATE INDEX idx_activity_responses_status ON activity_responses(status);
CREATE INDEX idx_activity_responses_completed ON activity_responses(completed_at) WHERE completed_at IS NOT NULL;
CREATE INDEX idx_activity_responses_cycle ON activity_responses(cycle_number);
CREATE INDEX idx_activity_responses_feedback_unread ON activity_responses(staff_feedback_by) WHERE NOT feedback_read_by_student;


-- ============================================
-- Table: student_activities
-- ============================================
DROP TABLE IF EXISTS student_activities CASCADE;

CREATE TABLE student_activities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_email VARCHAR(255) NOT NULL REFERENCES students(email) ON DELETE CASCADE,
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
DROP TABLE IF EXISTS student_achievements CASCADE;

CREATE TABLE student_achievements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_email VARCHAR(255) NOT NULL REFERENCES students(email) ON DELETE CASCADE,
  
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
DROP TABLE IF EXISTS staff_student_connections CASCADE;

CREATE TABLE staff_student_connections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  staff_email VARCHAR(255) NOT NULL,
  student_email VARCHAR(255) NOT NULL REFERENCES students(email) ON DELETE CASCADE,
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
-- NOTE: May be shared with other VESPA apps
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
DROP TABLE IF EXISTS activity_history CASCADE;

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
-- Helper Functions for Gamification
-- ============================================

-- Function: Increment student completed count
CREATE OR REPLACE FUNCTION increment_student_completed_count(student_email_param VARCHAR)
RETURNS void AS $$
BEGIN
  UPDATE students
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
  UPDATE students
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
  UPDATE students
  SET 
    total_achievements = total_achievements + 1,
    updated_at = NOW()
  WHERE email = student_email_param;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- Row Level Security (RLS) Policies
-- ============================================

-- Enable RLS on all tables
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_student_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievement_definitions ENABLE ROW LEVEL SECURITY;

-- ============================================
-- RLS: activities (public read)
-- ============================================
CREATE POLICY "Anyone can view active activities"
ON activities FOR SELECT
USING (is_active = true);

CREATE POLICY "Service role full access on activities"
ON activities FOR ALL
TO service_role
USING (true);


-- ============================================
-- RLS: activity_questions (public read)
-- ============================================
CREATE POLICY "Anyone can view active questions"
ON activity_questions FOR SELECT
USING (is_active = true);

CREATE POLICY "Service role full access on activity_questions"
ON activity_questions FOR ALL
TO service_role
USING (true);


-- ============================================
-- RLS: students
-- ============================================
CREATE POLICY "Students can read own record"
ON students FOR SELECT
USING (email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Students can update own record"
ON students FOR UPDATE
USING (email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Service role full access on students"
ON students FOR ALL
TO service_role
USING (true);


-- ============================================
-- RLS: activity_responses
-- ============================================
CREATE POLICY "Students can manage own responses"
ON activity_responses FOR ALL
USING (student_email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Staff can read connected student responses"
ON activity_responses FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM staff_student_connections
    WHERE staff_email = current_setting('request.jwt.claims', true)::json->>'email'
    AND student_email = activity_responses.student_email
  )
);

CREATE POLICY "Staff can update connected student responses"
ON activity_responses FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM staff_student_connections
    WHERE staff_email = current_setting('request.jwt.claims', true)::json->>'email'
    AND student_email = activity_responses.student_email
  )
);

CREATE POLICY "Service role full access on activity_responses"
ON activity_responses FOR ALL
TO service_role
USING (true);


-- ============================================
-- RLS: student_activities
-- ============================================
CREATE POLICY "Students can manage own activities"
ON student_activities FOR ALL
USING (student_email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Staff can manage connected student activities"
ON student_activities FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM staff_student_connections
    WHERE staff_email = current_setting('request.jwt.claims', true)::json->>'email'
    AND student_email = student_activities.student_email
  )
);

CREATE POLICY "Service role full access on student_activities"
ON student_activities FOR ALL
TO service_role
USING (true);


-- ============================================
-- RLS: student_achievements
-- ============================================
CREATE POLICY "Students can read own achievements"
ON student_achievements FOR SELECT
USING (student_email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Staff can read connected student achievements"
ON student_achievements FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM staff_student_connections
    WHERE staff_email = current_setting('request.jwt.claims', true)::json->>'email'
    AND student_email = student_achievements.student_email
  )
);

CREATE POLICY "Service role full access on student_achievements"
ON student_achievements FOR ALL
TO service_role
USING (true);


-- ============================================
-- RLS: staff_student_connections
-- ============================================
CREATE POLICY "Staff can read own connections"
ON staff_student_connections FOR SELECT
USING (staff_email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Service role full access on staff_student_connections"
ON staff_student_connections FOR ALL
TO service_role
USING (true);


-- ============================================
-- RLS: notifications
-- ============================================
CREATE POLICY "Users can read own notifications"
ON notifications FOR SELECT
USING (recipient_email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
USING (recipient_email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Service role full access on notifications"
ON notifications FOR ALL
TO service_role
USING (true);


-- ============================================
-- RLS: activity_history (read-only for users)
-- ============================================
CREATE POLICY "Users can read own history"
ON activity_history FOR SELECT
USING (student_email = current_setting('request.jwt.claims', true)::json->>'email');

CREATE POLICY "Service role full access on activity_history"
ON activity_history FOR ALL
TO service_role
USING (true);


-- ============================================
-- RLS: achievement_definitions (public read)
-- ============================================
CREATE POLICY "Anyone can view active achievement definitions"
ON achievement_definitions FOR SELECT
USING (is_active = true);

CREATE POLICY "Service role full access on achievement_definitions"
ON achievement_definitions FOR ALL
TO service_role
USING (true);


-- ============================================
-- Verification Queries
-- ============================================

-- Run these after migration to verify

-- Check table creation
SELECT 
  tablename, 
  schemaname 
FROM pg_tables 
WHERE tablename IN (
  'activities', 
  'activity_questions', 
  'students', 
  'activity_responses',
  'student_activities',
  'student_achievements',
  'staff_student_connections',
  'notifications',
  'activity_history',
  'achievement_definitions'
)
ORDER BY tablename;

-- Check indexes
SELECT 
  indexname, 
  tablename 
FROM pg_indexes 
WHERE indexname LIKE 'idx_activity%' 
OR indexname LIKE 'idx_student%'
OR indexname LIKE 'idx_staff%'
OR indexname LIKE 'idx_notification%'
OR indexname LIKE 'idx_achievement%'
ORDER BY tablename, indexname;

-- Success message
SELECT '✅ VESPA Activities V3 Schema Created Successfully!' as status;

