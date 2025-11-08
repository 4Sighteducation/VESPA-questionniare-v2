-- VESPA Questionnaire V2 - MINIMAL Schema Enhancements
-- Run this in Supabase SQL Editor
-- SAFE VERSION - Does NOT touch students table or existing sync logic
-- Only updates constraints needed for multi-year questionnaire support

-- ========================================
-- 1. UPDATE VESPA_SCORES FOR MULTI-YEAR SUPPORT
-- ========================================

-- Drop old constraint if it exists (was: student_id + cycle only)
ALTER TABLE vespa_scores 
DROP CONSTRAINT IF EXISTS vespa_scores_student_id_cycle_key;

-- Add new multi-year constraint (student_id + cycle + academic_year)
-- This allows same student to have Cycle 1 in both 2024/2025 and 2025/2026
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'vespa_scores_unique_per_year'
  ) THEN
    ALTER TABLE vespa_scores 
    ADD CONSTRAINT vespa_scores_unique_per_year 
    UNIQUE(student_id, cycle, academic_year);
  END IF;
END $$;

-- ========================================
-- 2. UPDATE QUESTION_RESPONSES FOR MULTI-YEAR SUPPORT
-- ========================================

-- Drop old constraint if it exists
ALTER TABLE question_responses 
DROP CONSTRAINT IF EXISTS question_responses_student_id_cycle_question_id_key;

-- Add new multi-year constraint
-- A student can only answer each question once per cycle per academic year
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'question_responses_unique_per_year'
  ) THEN
    ALTER TABLE question_responses 
    ADD CONSTRAINT question_responses_unique_per_year 
    UNIQUE(student_id, cycle, question_id, academic_year);
  END IF;
END $$;

-- ========================================
-- 3. ADD PERFORMANCE INDEXES (IF NOT EXISTS)
-- ========================================

-- Index for finding student's Cycle 1 to get locked academic year
CREATE INDEX IF NOT EXISTS idx_vespa_scores_cycle1_lookup 
ON vespa_scores(student_id, cycle, academic_year) 
WHERE cycle = 1;

-- Index for checking if student completed a cycle
CREATE INDEX IF NOT EXISTS idx_vespa_scores_completion 
ON vespa_scores(student_id, cycle, academic_year, completion_date);

-- Index for academic year queries
CREATE INDEX IF NOT EXISTS idx_vespa_scores_academic_year 
ON vespa_scores(academic_year);

CREATE INDEX IF NOT EXISTS idx_question_responses_academic_year 
ON question_responses(academic_year);

-- ========================================
-- 4. CREATE HELPER FUNCTION - GET LOCKED ACADEMIC YEAR
-- ========================================

-- Drop and recreate to ensure clean state
DROP FUNCTION IF EXISTS get_student_academic_year(UUID);

CREATE FUNCTION get_student_academic_year(p_student_id UUID)
RETURNS VARCHAR(10) AS $$
DECLARE
  locked_year VARCHAR(10);
BEGIN
  -- Try to find the student's Cycle 1 academic year (locked year)
  -- This is the "source of truth" - all cycles in same year use this value
  SELECT academic_year INTO locked_year
  FROM vespa_scores
  WHERE student_id = p_student_id 
    AND cycle = 1
  ORDER BY completion_date DESC
  LIMIT 1;
  
  RETURN locked_year;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- 5. CREATE VIEW - STUDENT QUESTIONNAIRE STATUS
-- ========================================

DROP VIEW IF EXISTS student_questionnaire_status;

CREATE VIEW student_questionnaire_status AS
SELECT 
  s.id as student_id,
  s.email,
  s.name,
  s.establishment_id,
  e.name as establishment_name,
  e.is_australian,
  -- Get current cycle (highest completed cycle)
  COALESCE(MAX(vs.cycle), 0) as current_cycle,
  -- Get locked academic year from Cycle 1
  get_student_academic_year(s.id) as locked_academic_year,
  -- Check which cycles are completed in CURRENT academic year
  BOOL_OR(vs.cycle = 1 AND vs.academic_year = get_student_academic_year(s.id)) as cycle1_completed,
  BOOL_OR(vs.cycle = 2 AND vs.academic_year = get_student_academic_year(s.id)) as cycle2_completed,
  BOOL_OR(vs.cycle = 3 AND vs.academic_year = get_student_academic_year(s.id)) as cycle3_completed,
  -- Get latest completion date
  MAX(vs.completion_date) as last_completion_date,
  -- Count total cycles completed across all years
  COUNT(DISTINCT vs.id) as total_cycles_completed
FROM students s
LEFT JOIN establishments e ON s.establishment_id = e.id
LEFT JOIN vespa_scores vs ON s.id = vs.student_id
GROUP BY s.id, s.email, s.name, s.establishment_id, e.name, e.is_australian;

-- ========================================
-- 6. ADD COMMENTS FOR DOCUMENTATION
-- ========================================

COMMENT ON CONSTRAINT vespa_scores_unique_per_year ON vespa_scores IS 
  'Allows same student to have multiple academic years (e.g., Year 12 in 2024/2025 and Year 13 in 2025/2026)';

COMMENT ON CONSTRAINT question_responses_unique_per_year ON question_responses IS 
  'Prevents duplicate responses for same question in same cycle and academic year';

COMMENT ON FUNCTION get_student_academic_year IS 
  'Returns the locked academic year from student''s Cycle 1. All subsequent cycles (2 & 3) must use this same academic_year value.';

COMMENT ON VIEW student_questionnaire_status IS 
  'Quick lookup for student''s current questionnaire status. Use this to check eligibility before allowing questionnaire access.';

-- ========================================
-- 7. TEST QUERIES (Optional - verify setup)
-- ========================================

-- Test 1: Check constraints are in place
SELECT 
  conname as constraint_name,
  pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid IN ('vespa_scores'::regclass, 'question_responses'::regclass)
  AND conname LIKE '%unique%';

-- Test 2: Check helper function works
SELECT get_student_academic_year('00000000-0000-0000-0000-000000000000'::UUID);

-- Test 3: Check view is created
SELECT COUNT(*) as view_exists 
FROM information_schema.views 
WHERE table_name = 'student_questionnaire_status';

-- ========================================
-- DONE! Schema ready for Questionnaire V2
-- Your existing sync script is UNTOUCHED
-- ========================================
