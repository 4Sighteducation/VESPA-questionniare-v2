-- DIAGNOSTIC SCRIPT - Check what's currently in Supabase
-- Run this to see what changes were made and if anything needs reverting

-- ========================================
-- 1. CHECK STUDENTS TABLE STRUCTURE
-- ========================================

SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'students'
ORDER BY ordinal_position;

-- ========================================
-- 2. CHECK STUDENTS TABLE CONSTRAINTS
-- ========================================

SELECT 
  conname as constraint_name,
  pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'students'::regclass;

-- ========================================
-- 3. CHECK VESPA_SCORES CONSTRAINTS
-- ========================================

SELECT 
  conname as constraint_name,
  pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'vespa_scores'::regclass
  AND contype = 'u'; -- Only unique constraints

-- ========================================
-- 4. CHECK QUESTION_RESPONSES CONSTRAINTS
-- ========================================

SELECT 
  conname as constraint_name,
  pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'question_responses'::regclass
  AND contype = 'u'; -- Only unique constraints

-- ========================================
-- 5. CHECK FOR calculate_academic_year FUNCTION
-- ========================================

SELECT 
  p.proname as function_name,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_functiondef(p.oid) as definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'calculate_academic_year'
  AND n.nspname = 'public';

-- ========================================
-- 6. CHECK FOR get_student_academic_year FUNCTION
-- ========================================

SELECT 
  p.proname as function_name,
  pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'get_student_academic_year'
  AND n.nspname = 'public';

-- ========================================
-- 7. CHECK FOR student_questionnaire_status VIEW
-- ========================================

SELECT 
  viewname,
  definition
FROM pg_views
WHERE viewname = 'student_questionnaire_status';

-- ========================================
-- 8. CHECK INDEXES
-- ========================================

SELECT 
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename IN ('vespa_scores', 'question_responses')
  AND indexname LIKE '%academic_year%'
ORDER BY tablename, indexname;

-- ========================================
-- SUMMARY OF FINDINGS
-- ========================================
-- After running this, you'll see:
-- - If students table has new academic_year column (we need to check this)
-- - If students table has new constraints (might break sync)
-- - Current vespa_scores and question_responses constraints
-- - What functions were created
-- - What indexes exist
-- ========================================

