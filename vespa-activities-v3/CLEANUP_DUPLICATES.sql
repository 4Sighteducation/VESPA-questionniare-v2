-- ============================================
-- VESPA Activities V3 - Cleanup Duplicate Students
-- ============================================
-- SAFE SCRIPT: Deletes duplicate student records (keeps oldest)
-- Run this BEFORE the main schema migration

-- ============================================
-- Step 1: Review Duplicates (READ-ONLY)
-- ============================================
-- Run this first to see what will be deleted

SELECT 
  email,
  knack_id,
  COUNT(*) as duplicate_count,
  STRING_AGG(id::text, ', ' ORDER BY created_at) as record_ids,
  MIN(created_at) as oldest_record,
  MAX(created_at) as newest_record
FROM students
WHERE knack_id IS NOT NULL
GROUP BY email, knack_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- This shows you all duplicates by email + knack_id combination


-- ============================================
-- Step 2: SAFE DELETION of Duplicates
-- ============================================
-- This keeps the OLDEST record for each email (by created_at)
-- Deletes all newer duplicates

-- UNCOMMENT THE LINES BELOW TO RUN THE DELETION:

/*
DO $$
DECLARE
  deleted_count INTEGER;
BEGIN
  -- Delete duplicate records, keeping only the oldest per email
  WITH duplicates AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_at ASC) as rn
    FROM students
  )
  DELETE FROM students
  WHERE id IN (
    SELECT id FROM duplicates WHERE rn > 1
  );
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  RAISE NOTICE 'Deleted % duplicate student records', deleted_count;
END
$$;
*/

-- After deletion, verify no duplicates remain:
-- SELECT email, COUNT(*) FROM students GROUP BY email HAVING COUNT(*) > 1;


-- ============================================
-- Step 3: After Cleanup - Update knack_id Duplicates
-- ============================================
-- Some students might still have duplicate knack_ids if they have
-- different emails (e.g., email typo in one record)
-- This sets those to NULL to allow unique index

/*
UPDATE students
SET knack_id = NULL
WHERE id IN (
  SELECT id
  FROM (
    SELECT id, knack_id,
           ROW_NUMBER() OVER (PARTITION BY knack_id ORDER BY created_at) as rn
    FROM students
    WHERE knack_id IS NOT NULL
  ) t
  WHERE rn > 1
);
*/


-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check no email duplicates remain
SELECT 
  email, 
  COUNT(*) as count,
  STRING_AGG(id::text, ', ') as ids
FROM students
GROUP BY email
HAVING COUNT(*) > 1;

-- Should return 0 rows

-- Check no knack_id duplicates remain
SELECT 
  knack_id, 
  COUNT(*) as count,
  STRING_AGG(email, ', ') as emails
FROM students
WHERE knack_id IS NOT NULL
GROUP BY knack_id
HAVING COUNT(*) > 1;

-- Should return 0 rows

-- Total students after cleanup
SELECT COUNT(*) as total_students FROM students;


