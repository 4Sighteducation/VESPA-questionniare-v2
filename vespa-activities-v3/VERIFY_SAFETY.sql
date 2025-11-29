-- ============================================
-- VESPA Activities V3 - Safety Verification
-- ============================================
-- Run this BEFORE cleanup to verify it won't break anything

-- ============================================
-- Step 1: Check ALL foreign key relationships to students table
-- ============================================
SELECT
  tc.table_name AS referencing_table,
  kcu.column_name AS referencing_column,
  ccu.table_name AS referenced_table,
  ccu.column_name AS referenced_column
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND ccu.table_name = 'students'
ORDER BY tc.table_name;

-- This shows ALL tables that reference students table
-- If column is 'email' → SAFE (email stays same after cleanup)
-- If column is 'id' → NEED TO CHECK (record ID changes)


-- ============================================
-- Step 2: Check vespa_scores table structure
-- ============================================
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'vespa_scores'
  AND column_name LIKE '%student%'
ORDER BY ordinal_position;

-- Expected: student_email (VARCHAR) ✅ SAFE
-- NOT: student_id (UUID) ⚠️ UNSAFE


-- ============================================
-- Step 3: Check question_responses table structure
-- ============================================
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'question_responses'
  AND column_name LIKE '%student%'
ORDER BY ordinal_position;

-- Expected: student_email (VARCHAR) ✅ SAFE
-- NOT: student_id (UUID) ⚠️ UNSAFE


-- ============================================
-- Step 4: List ALL tables in your schema
-- ============================================
SELECT 
  tablename,
  schemaname
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename NOT LIKE 'pg_%'
  AND tablename NOT LIKE 'sql_%'
ORDER BY tablename;

-- This shows all tables in your Supabase project


-- ============================================
-- Step 5: Count records that would be affected by cleanup
-- ============================================

-- How many duplicate students will be deleted?
WITH duplicates AS (
  SELECT id,
         ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_at ASC) as rn
  FROM students
)
SELECT COUNT(*) as will_be_deleted
FROM duplicates
WHERE rn > 1;

-- How many vespa_scores are linked to duplicate emails?
WITH duplicate_emails AS (
  SELECT email
  FROM students
  GROUP BY email
  HAVING COUNT(*) > 1
)
SELECT COUNT(*) as vespa_scores_count
FROM vespa_scores
WHERE student_email IN (SELECT email FROM duplicate_emails);

-- CRITICAL: These scores won't be deleted, just linked to one student record instead of two


-- ============================================
-- SAFETY SUMMARY
-- ============================================

-- If Step 1 shows foreign keys are on 'email' columns → ✅ SAFE
-- If Step 1 shows foreign keys are on 'id' columns → ⚠️ NEED DIFFERENT APPROACH

-- The cleanup deletes rows from students table only
-- If other tables reference by EMAIL → they're unaffected
-- If other tables reference by ID → they would break


