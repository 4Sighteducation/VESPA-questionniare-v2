-- ============================================================================
-- CLEAN EMAIL HTML TAGS
-- ============================================================================
-- Purpose: Fix emails stored with HTML anchor tags
-- Date: December 1, 2025
--
-- Issue: Some emails stored as: <a href="mailto:email@x.com">email@x.com</a>
--        Causes lookup failures and duplicate records
--
-- Solution: Extract clean email, update records, merge duplicates
-- ============================================================================

-- ============================================================================
-- STEP 1: ANALYZE THE PROBLEM
-- ============================================================================

-- 1.1: Find emails with HTML tags
SELECT 
  'vespa_students' as table_name,
  COUNT(*) as count_with_html
FROM vespa_students
WHERE email LIKE '%<a href%' OR email LIKE '%mailto:%'
UNION ALL
SELECT 
  'vespa_accounts',
  COUNT(*)
FROM vespa_accounts
WHERE email LIKE '%<a href%' OR email LIKE '%mailto:%'
UNION ALL
SELECT 
  'activity_responses',
  COUNT(*)
FROM activity_responses
WHERE student_email LIKE '%<a href%' OR student_email LIKE '%mailto:%';

-- 1.2: Sample of emails with HTML tags
SELECT 
  email as original_email,
  regexp_replace(email, '<a href="mailto:([^"]+)".*', '\1') as clean_email,
  full_name,
  school_name
FROM vespa_students
WHERE email LIKE '%<a href%'
LIMIT 20;

-- 1.3: Find potential duplicates (same clean email, different formats)
WITH email_variants AS (
  SELECT 
    id,
    email as original_email,
    CASE 
      WHEN email LIKE '%<a href%' THEN 
        regexp_replace(email, '<a href="mailto:([^"]+)".*', '\1')
      WHEN email LIKE '%mailto:%' THEN
        regexp_replace(email, '.*mailto:([^">]+).*', '\1')
      ELSE email
    END as clean_email
  FROM vespa_students
)
SELECT 
  clean_email,
  COUNT(*) as variant_count,
  array_agg(original_email) as email_variants,
  array_agg(id) as student_ids
FROM email_variants
GROUP BY clean_email
HAVING COUNT(*) > 1
ORDER BY variant_count DESC;

-- ============================================================================
-- STEP 2: CREATE CLEANING FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION clean_email(email_input TEXT)
RETURNS TEXT AS $$
DECLARE
  cleaned TEXT;
BEGIN
  IF email_input IS NULL OR email_input = '' THEN
    RETURN NULL;
  END IF;
  
  -- Remove HTML anchor tags
  IF email_input LIKE '%<a href%' OR email_input LIKE '%mailto:%' THEN
    -- Extract email from mailto: link
    cleaned := regexp_replace(email_input, '.*mailto:([^"''>]+).*', '\1');
    
    -- If that didn't work, try stripping all HTML
    IF cleaned = email_input THEN
      cleaned := regexp_replace(email_input, '<[^>]*>', '', 'g');
    END IF;
    
    -- Trim whitespace
    cleaned := TRIM(cleaned);
    
    -- Convert to lowercase
    cleaned := LOWER(cleaned);
    
    RETURN cleaned;
  ELSE
    -- Already clean, just trim and lowercase
    RETURN LOWER(TRIM(email_input));
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Test the function
SELECT 
  original,
  clean_email(original) as cleaned
FROM (VALUES
  ('<a href="mailto:test@school.com">test@school.com</a>'),
  ('student@example.com'),
  ('  Student@Example.com  '),
  ('<a href="mailto:user@vespa.academy" class="link">user@vespa.academy</a>')
) AS t(original);

-- ============================================================================
-- STEP 3: DRY RUN - Preview Changes
-- ============================================================================

-- 3.1: Preview vespa_students updates
SELECT 
  id,
  email as old_email,
  clean_email(email) as new_email,
  full_name,
  school_name,
  CASE 
    WHEN email = clean_email(email) THEN 'No change'
    ELSE 'Will update'
  END as action
FROM vespa_students
WHERE email LIKE '%<a href%' OR email LIKE '%mailto:%'
   OR email != LOWER(TRIM(email))
ORDER BY action DESC, email
LIMIT 50;

-- 3.2: Count how many records will be updated
SELECT 
  COUNT(*) as records_to_update
FROM vespa_students
WHERE email LIKE '%<a href%' OR email LIKE '%mailto:%'
   OR email != LOWER(TRIM(email));

-- ============================================================================
-- STEP 4: BACKUP BEFORE CLEANING (IMPORTANT!)
-- ============================================================================

-- Create backup table
DROP TABLE IF EXISTS vespa_students_email_backup;
CREATE TABLE vespa_students_email_backup AS
SELECT id, email, full_name, school_id, created_at, updated_at
FROM vespa_students
WHERE email LIKE '%<a href%' OR email LIKE '%mailto:%'
   OR email != LOWER(TRIM(email));

-- Verify backup
SELECT COUNT(*) as backed_up_records FROM vespa_students_email_backup;

-- ============================================================================
-- STEP 5: CLEAN EMAILS IN vespa_students
-- ============================================================================

-- 5.1: Update emails to clean versions
UPDATE vespa_students
SET 
  email = clean_email(email),
  updated_at = NOW()
WHERE email LIKE '%<a href%' OR email LIKE '%mailto:%'
   OR email != LOWER(TRIM(email));

-- Check how many updated
SELECT COUNT(*) as updated_count FROM vespa_students WHERE updated_at > NOW() - INTERVAL '1 minute';

-- ============================================================================
-- STEP 6: CLEAN EMAILS IN vespa_accounts
-- ============================================================================

-- 6.1: Backup
DROP TABLE IF EXISTS vespa_accounts_email_backup;
CREATE TABLE vespa_accounts_email_backup AS
SELECT id, email, full_name, account_type, created_at
FROM vespa_accounts
WHERE email LIKE '%<a href%' OR email LIKE '%mailto:%'
   OR email != LOWER(TRIM(email));

-- 6.2: Update
UPDATE vespa_accounts
SET 
  email = clean_email(email),
  updated_at = NOW()
WHERE email LIKE '%<a href%' OR email LIKE '%mailto:%'
   OR email != LOWER(TRIM(email));

-- ============================================================================
-- STEP 7: CLEAN EMAILS IN activity_responses
-- ============================================================================

-- 7.1: Backup
DROP TABLE IF EXISTS activity_responses_email_backup;
CREATE TABLE activity_responses_email_backup AS
SELECT id, student_email, activity_id, status, created_at
FROM activity_responses
WHERE student_email LIKE '%<a href%' OR student_email LIKE '%mailto:%'
   OR student_email != LOWER(TRIM(student_email));

-- 7.2: Update
UPDATE activity_responses
SET 
  student_email = clean_email(student_email),
  updated_at = NOW()
WHERE student_email LIKE '%<a href%' OR student_email LIKE '%mailto:%'
   OR student_email != LOWER(TRIM(student_email));

-- ============================================================================
-- STEP 8: HANDLE DUPLICATES (AFTER CLEANING)
-- ============================================================================

-- 8.1: Find duplicate students (same email after cleaning)
WITH duplicate_students AS (
  SELECT 
    email,
    COUNT(*) as count,
    array_agg(id ORDER BY created_at ASC) as student_ids,
    array_agg(full_name) as names,
    array_agg(school_id) as school_ids
  FROM vespa_students
  GROUP BY email
  HAVING COUNT(*) > 1
)
SELECT 
  email,
  count as duplicate_count,
  student_ids,
  names,
  school_ids
FROM duplicate_students
ORDER BY count DESC;

-- 8.2: Merge duplicate students (MANUAL REVIEW REQUIRED!)
-- For each duplicate, we'll keep the oldest record and merge data

-- Template for merging (RUN MANUALLY for each duplicate):
/*
DO $$
DECLARE
  keep_id UUID := 'UUID_OF_RECORD_TO_KEEP';
  delete_id UUID := 'UUID_OF_DUPLICATE_TO_DELETE';
BEGIN
  -- Update activity_responses to point to kept student
  UPDATE activity_responses
  SET student_email = (SELECT email FROM vespa_students WHERE id = keep_id)
  WHERE student_email = (SELECT email FROM vespa_students WHERE id = delete_id);
  
  -- Update user_connections
  UPDATE user_connections
  SET student_account_id = (SELECT account_id FROM vespa_students WHERE id = keep_id)
  WHERE student_account_id = (SELECT account_id FROM vespa_students WHERE id = delete_id);
  
  -- Merge missing fields from duplicate to kept record
  UPDATE vespa_students
  SET 
    full_name = COALESCE(full_name, (SELECT full_name FROM vespa_students WHERE id = delete_id)),
    school_id = COALESCE(school_id, (SELECT school_id FROM vespa_students WHERE id = delete_id)),
    school_name = COALESCE(school_name, (SELECT school_name FROM vespa_students WHERE id = delete_id)),
    current_year_group = COALESCE(current_year_group, (SELECT current_year_group FROM vespa_students WHERE id = delete_id)),
    student_group = COALESCE(student_group, (SELECT student_group FROM vespa_students WHERE id = delete_id))
  WHERE id = keep_id;
  
  -- Delete duplicate
  DELETE FROM vespa_students WHERE id = delete_id;
  
  RAISE NOTICE 'Merged and deleted duplicate: %', delete_id;
END $$;
*/

-- ============================================================================
-- STEP 9: VERIFICATION
-- ============================================================================

-- 9.1: Check no more HTML tags
SELECT 
  'vespa_students' as table_name,
  COUNT(*) as remaining_html_emails
FROM vespa_students
WHERE email LIKE '%<a href%' OR email LIKE '%mailto:%'
UNION ALL
SELECT 
  'vespa_accounts',
  COUNT(*)
FROM vespa_accounts
WHERE email LIKE '%<a href%' OR email LIKE '%mailto:%'
UNION ALL
SELECT 
  'activity_responses',
  COUNT(*)
FROM activity_responses
WHERE student_email LIKE '%<a href%' OR student_email LIKE '%mailto:%';

-- 9.2: Check for remaining duplicates
SELECT 
  email,
  COUNT(*) as count
FROM vespa_students
GROUP BY email
HAVING COUNT(*) > 1;

-- 9.3: Sample cleaned emails
SELECT 
  vs.email,
  vs.full_name,
  vs.school_name,
  COUNT(ar.id) as activity_count
FROM vespa_students vs
LEFT JOIN activity_responses ar ON ar.student_email = vs.email
WHERE vs.updated_at > NOW() - INTERVAL '5 minutes'
GROUP BY vs.email, vs.full_name, vs.school_name
ORDER BY activity_count DESC
LIMIT 20;

-- ============================================================================
-- ROLLBACK SCRIPT (IF NEEDED)
-- ============================================================================

-- Restore from backup if something went wrong:
/*
-- Restore vespa_students
UPDATE vespa_students vs
SET email = backup.email
FROM vespa_students_email_backup backup
WHERE vs.id = backup.id;

-- Restore vespa_accounts
UPDATE vespa_accounts va
SET email = backup.email
FROM vespa_accounts_email_backup backup
WHERE va.id = backup.id;

-- Restore activity_responses
UPDATE activity_responses ar
SET student_email = backup.student_email
FROM activity_responses_email_backup backup
WHERE ar.id = backup.id;
*/

-- ============================================================================
-- CLEANUP (AFTER VERIFICATION)
-- ============================================================================

-- Drop backup tables (only after verifying everything works!)
/*
DROP TABLE IF EXISTS vespa_students_email_backup;
DROP TABLE IF EXISTS vespa_accounts_email_backup;
DROP TABLE IF EXISTS activity_responses_email_backup;
*/

-- ============================================================================
-- END OF SCRIPT
-- ============================================================================

-- Summary query to run after all steps
SELECT 
  'Cleaned emails' as status,
  NOW() as completed_at;

