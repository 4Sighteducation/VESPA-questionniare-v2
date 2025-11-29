-- ============================================
-- VESPA Activities V3 - Complete Cleanup
-- ============================================
-- Run this FIRST to drop ALL activity tables
-- Then run FUTURE_READY_SCHEMA.sql
-- ============================================

-- Drop all tables (order matters - dependencies first)
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS activity_history CASCADE;
DROP TABLE IF EXISTS staff_student_connections CASCADE;
DROP TABLE IF EXISTS student_achievements CASCADE;
DROP TABLE IF EXISTS student_activities CASCADE;
DROP TABLE IF EXISTS activity_responses CASCADE;
DROP TABLE IF EXISTS activity_questions CASCADE;
DROP TABLE IF EXISTS activities CASCADE;
DROP TABLE IF EXISTS vespa_students CASCADE;
DROP TABLE IF EXISTS vespa_staff CASCADE;
DROP TABLE IF EXISTS achievement_definitions CASCADE;

-- Drop any leftover indexes
DROP INDEX IF EXISTS idx_activity_library_category CASCADE;
DROP INDEX IF EXISTS idx_activity_library_level CASCADE;
DROP INDEX IF EXISTS idx_activity_library_active CASCADE;
DROP INDEX IF EXISTS idx_activity_library_thresholds CASCADE;
DROP INDEX IF EXISTS idx_activity_library_problem_mappings CASCADE;
DROP INDEX IF EXISTS idx_activity_library_slug CASCADE;
DROP INDEX IF EXISTS idx_activity_questions_activity CASCADE;
DROP INDEX IF EXISTS idx_activity_questions_order CASCADE;
DROP INDEX IF EXISTS idx_activity_questions_active CASCADE;
DROP INDEX IF EXISTS idx_vespa_students_email CASCADE;
DROP INDEX IF EXISTS idx_vespa_students_current_knack_id CASCADE;
DROP INDEX IF EXISTS idx_vespa_students_supabase_user_id CASCADE;
DROP INDEX IF EXISTS idx_vespa_students_historical_knack_ids CASCADE;
DROP INDEX IF EXISTS idx_vespa_students_active CASCADE;
DROP INDEX IF EXISTS idx_vespa_students_school CASCADE;
DROP INDEX IF EXISTS idx_vespa_students_year_group CASCADE;
DROP INDEX IF EXISTS idx_vespa_students_academic_year CASCADE;
DROP INDEX IF EXISTS idx_vespa_students_status CASCADE;

-- Drop helper functions
DROP FUNCTION IF EXISTS get_or_create_vespa_student CASCADE;
DROP FUNCTION IF EXISTS sync_vespa_scores_to_vespa_student CASCADE;
DROP FUNCTION IF EXISTS handle_student_year_rollover CASCADE;
DROP FUNCTION IF EXISTS increment_student_completed_count CASCADE;
DROP FUNCTION IF EXISTS add_student_points CASCADE;
DROP FUNCTION IF EXISTS increment_student_achievement_count CASCADE;
DROP FUNCTION IF EXISTS get_or_create_vespa_staff CASCADE;

-- Drop views
DROP VIEW IF EXISTS legacy_students_bridge CASCADE;

-- Verify cleanup
SELECT 
  tablename 
FROM pg_tables 
WHERE tablename IN (
  'activities',
  'activity_questions',
  'vespa_students',
  'activity_responses',
  'student_activities',
  'student_achievements',
  'staff_student_connections',
  'notifications',
  'activity_history',
  'achievement_definitions',
  'vespa_staff'
)
ORDER BY tablename;

-- Should return 0 rows

SELECT '✅ Cleanup complete! Now run FUTURE_READY_SCHEMA.sql' as message;

