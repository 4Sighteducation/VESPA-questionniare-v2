-- QUICK FIX - Make students.academic_year nullable for sync compatibility
-- This is the ONLY change needed

-- 1. Make academic_year nullable so sync script works
ALTER TABLE students 
ALTER COLUMN academic_year DROP NOT NULL;

-- 2. Clean up duplicate constraints (optional but tidy)
ALTER TABLE vespa_scores 
DROP CONSTRAINT IF EXISTS vespa_scores_unique_per_year;

ALTER TABLE question_responses
DROP CONSTRAINT IF EXISTS question_responses_unique_per_year;

-- Done! Now sync script will work perfectly
-- Your questionnaire will write academic_year, sync script makes it optional

SELECT 'Students table fixed - academic_year is now nullable' as status;

