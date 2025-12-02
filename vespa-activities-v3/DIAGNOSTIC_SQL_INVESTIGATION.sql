-- ============================================================================
-- 🚨 ORPHANED RECORDS DIAGNOSTIC SQL
-- ============================================================================
-- Purpose: Investigate 19% orphaned student records (4,822 out of 24,923)
-- Date: December 1, 2025
-- ============================================================================

-- ============================================================================
-- SECTION 1: OVERALL HEALTH CHECK
-- ============================================================================

-- 1.1: Total students and orphan count
SELECT 
  COUNT(*) as total_students,
  COUNT(*) FILTER (WHERE school_id IS NULL) as orphaned_students,
  COUNT(*) FILTER (WHERE school_name IS NULL) as missing_school_name,
  ROUND(100.0 * COUNT(*) FILTER (WHERE school_id IS NULL) / COUNT(*), 2) as orphan_percentage
FROM vespa_students;

-- 1.2: Students with NULL full_name
SELECT 
  COUNT(*) as students_missing_name,
  COUNT(*) FILTER (WHERE school_id IS NULL) as orphaned_and_missing_name
FROM vespa_students
WHERE full_name IS NULL OR full_name = '';

-- 1.3: Students with email HTML tags
SELECT 
  COUNT(*) as students_with_html_emails,
  email
FROM vespa_students
WHERE email LIKE '%<a href%' OR email LIKE '%mailto:%'
GROUP BY email
LIMIT 20;

-- ============================================================================
-- SECTION 2: ESTABLISHMENTS INVESTIGATION
-- ============================================================================

-- 2.1: Count establishments (schools) in database
SELECT 
  COUNT(*) as total_establishments,
  COUNT(*) FILTER (WHERE is_australian = true) as australian_schools,
  COUNT(*) FILTER (WHERE knack_id IS NOT NULL) as with_knack_id
FROM establishments;

-- 2.2: List all establishments with student counts
SELECT 
  e.id as establishment_uuid,
  e.name as school_name,
  e.knack_id as knack_customer_id,
  COUNT(vs.id) as student_count,
  e.is_australian,
  e.created_at
FROM establishments e
LEFT JOIN vespa_students vs ON vs.school_id = e.id
GROUP BY e.id, e.name, e.knack_id, e.is_australian, e.created_at
ORDER BY student_count DESC;

-- 2.3: Find Coffs Harbour Senior College specifically
SELECT 
  e.id,
  e.name,
  e.knack_id,
  COUNT(vs.id) as students_in_supabase
FROM establishments e
LEFT JOIN vespa_students vs ON vs.school_id = e.id
WHERE e.name ILIKE '%coffs%' OR e.name ILIKE '%harbour%'
GROUP BY e.id, e.name, e.knack_id;

-- ============================================================================
-- SECTION 3: ORPHANED STUDENTS ANALYSIS
-- ============================================================================

-- 3.1: Sample of orphaned students (first 50)
SELECT 
  email,
  full_name,
  first_name,
  last_name,
  current_year_group,
  student_group,
  current_knack_id,
  created_at,
  last_synced_from_knack
FROM vespa_students
WHERE school_id IS NULL
ORDER BY created_at DESC
LIMIT 50;

-- 3.2: Orphaned students grouped by creation date
SELECT 
  DATE(created_at) as creation_date,
  COUNT(*) as orphaned_count
FROM vespa_students
WHERE school_id IS NULL
GROUP BY DATE(created_at)
ORDER BY creation_date DESC;

-- 3.3: Orphaned students with activities (should have school!)
SELECT 
  vs.email,
  vs.full_name,
  vs.school_id,
  vs.school_name,
  COUNT(ar.id) as activity_count
FROM vespa_students vs
LEFT JOIN activity_responses ar ON ar.student_email = vs.email
WHERE vs.school_id IS NULL
GROUP BY vs.email, vs.full_name, vs.school_id, vs.school_name
HAVING COUNT(ar.id) > 0
ORDER BY activity_count DESC
LIMIT 50;

-- 3.4: Orphaned students by knack_user_attributes school reference
-- (Check if school data exists in JSON but wasn't extracted)
SELECT 
  email,
  full_name,
  school_id,
  school_name,
  knack_user_attributes->'field_133' as knack_school_field,
  knack_user_attributes->'field_133_raw' as knack_school_raw,
  current_knack_id
FROM vespa_students
WHERE school_id IS NULL
  AND knack_user_attributes IS NOT NULL
LIMIT 50;

-- ============================================================================
-- SECTION 4: ACTIVITY RESPONSES INVESTIGATION
-- ============================================================================

-- 4.1: Activity responses with empty responses JSONB
SELECT 
  COUNT(*) as total_responses,
  COUNT(*) FILTER (WHERE responses = '{}') as empty_responses,
  COUNT(*) FILTER (WHERE responses_text IS NULL OR responses_text = '') as no_text_responses,
  ROUND(100.0 * COUNT(*) FILTER (WHERE responses = '{}') / COUNT(*), 2) as empty_percentage
FROM activity_responses;

-- 4.2: Sample of activities with status=completed but empty responses
SELECT 
  ar.student_email,
  vs.full_name,
  vs.school_name,
  a.name as activity_name,
  ar.status,
  ar.completed_at,
  ar.responses,
  ar.responses_text,
  ar.knack_id
FROM activity_responses ar
JOIN activities a ON a.id = ar.activity_id
LEFT JOIN vespa_students vs ON vs.email = ar.student_email
WHERE ar.status = 'completed'
  AND ar.responses = '{}'
LIMIT 50;

-- 4.3: Alena Ramsey specific check
SELECT 
  ar.student_email,
  a.name as activity_name,
  ar.status,
  ar.completed_at,
  ar.responses,
  LENGTH(ar.responses::text) as response_length,
  ar.responses_text,
  ar.knack_id
FROM activity_responses ar
JOIN activities a ON a.id = ar.activity_id
WHERE ar.student_email = 'aramsey@vespa.academy'
ORDER BY ar.completed_at DESC;

-- ============================================================================
-- SECTION 5: DATA SOURCE COMPARISON
-- ============================================================================

-- 5.1: Students in vespa_students vs vespa_accounts (should match or vespa_accounts >= vespa_students)
SELECT 
  (SELECT COUNT(*) FROM vespa_accounts WHERE account_type = 'student') as accounts_students,
  (SELECT COUNT(*) FROM vespa_students) as vespa_students_count,
  (SELECT COUNT(*) FROM vespa_accounts WHERE account_type = 'student') - 
    (SELECT COUNT(*) FROM vespa_students) as difference;

-- 5.2: Students in vespa_students with NO vespa_accounts entry (orphaned)
SELECT 
  vs.email,
  vs.full_name,
  vs.school_id,
  vs.account_id
FROM vespa_students vs
LEFT JOIN vespa_accounts va ON va.id = vs.account_id
WHERE va.id IS NULL
LIMIT 50;

-- 5.3: vespa_accounts students with school_id but vespa_students without
SELECT 
  va.email,
  va.full_name,
  va.school_id as account_school_id,
  va.school_name as account_school_name,
  vs.school_id as student_school_id,
  vs.school_name as student_school_name
FROM vespa_accounts va
LEFT JOIN vespa_students vs ON vs.account_id = va.id
WHERE va.account_type = 'student'
  AND va.school_id IS NOT NULL
  AND (vs.school_id IS NULL OR vs.school_id != va.school_id)
LIMIT 50;

-- ============================================================================
-- SECTION 6: STAFF CONNECTIONS INVESTIGATION
-- ============================================================================

-- 6.1: Students with NO staff connections (should be visible to nobody!)
SELECT 
  vs.email,
  vs.full_name,
  vs.school_name,
  vs.current_year_group,
  COUNT(uc.id) as connection_count
FROM vespa_students vs
LEFT JOIN user_connections uc ON uc.student_account_id = (
  SELECT id FROM vespa_accounts WHERE email = vs.email
)
GROUP BY vs.email, vs.full_name, vs.school_name, vs.current_year_group
HAVING COUNT(uc.id) = 0
ORDER BY vs.school_name, vs.email
LIMIT 100;

-- 6.2: Orphaned students with connections (impossible - connections need school match!)
SELECT 
  vs.email,
  vs.school_id,
  vs.school_name,
  COUNT(uc.id) as connection_count
FROM vespa_students vs
JOIN vespa_accounts va ON va.email = vs.email
LEFT JOIN user_connections uc ON uc.student_account_id = va.id
WHERE vs.school_id IS NULL
GROUP BY vs.email, vs.school_id, vs.school_name
HAVING COUNT(uc.id) > 0;

-- ============================================================================
-- SECTION 7: SYNC STATUS INVESTIGATION
-- ============================================================================

-- 7.1: Students never synced from Knack
SELECT 
  COUNT(*) as never_synced,
  COUNT(*) FILTER (WHERE school_id IS NULL) as never_synced_and_orphaned
FROM vespa_students
WHERE last_synced_from_knack IS NULL;

-- 7.2: Students by sync source (check created_by field)
SELECT 
  created_by,
  COUNT(*) as student_count,
  COUNT(*) FILTER (WHERE school_id IS NULL) as orphaned_count
FROM vespa_students
GROUP BY created_by
ORDER BY student_count DESC;

-- 7.3: Recent student creations (last 7 days)
SELECT 
  DATE(created_at) as date,
  COUNT(*) as students_created,
  COUNT(*) FILTER (WHERE school_id IS NULL) as orphaned,
  COUNT(*) FILTER (WHERE school_id IS NOT NULL) as with_school
FROM vespa_students
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- ============================================================================
-- SECTION 8: KNACK ID TO ESTABLISHMENT MAPPING
-- ============================================================================

-- 8.1: Check if knack_user_attributes contains establishment references
SELECT 
  vs.email,
  vs.school_id,
  vs.current_knack_id,
  vs.knack_user_attributes->'field_133' as knack_establishment_field,
  vs.knack_user_attributes->'field_133_raw' as knack_establishment_raw,
  e.id as matching_establishment_uuid,
  e.name as matching_establishment_name
FROM vespa_students vs
LEFT JOIN LATERAL (
  SELECT id, name, knack_id
  FROM establishments
  WHERE knack_id = vs.knack_user_attributes->'field_133_raw'->0->>'id'
  LIMIT 1
) e ON true
WHERE vs.school_id IS NULL
  AND vs.knack_user_attributes IS NOT NULL
LIMIT 100;

-- ============================================================================
-- SECTION 9: EMAIL HTML TAG ISSUES
-- ============================================================================

-- 9.1: Find duplicate emails (one clean, one with HTML)
WITH email_variants AS (
  SELECT 
    CASE 
      WHEN email LIKE '%<a href%' THEN 
        regexp_replace(email, '<a href="mailto:([^"]+)".*', '\1')
      ELSE email
    END as clean_email,
    email as original_email,
    id
  FROM vespa_students
)
SELECT 
  clean_email,
  COUNT(*) as variant_count,
  array_agg(DISTINCT original_email) as email_variants,
  array_agg(id) as student_ids
FROM email_variants
GROUP BY clean_email
HAVING COUNT(*) > 1
LIMIT 50;

-- ============================================================================
-- SECTION 10: SCHOOL-SPECIFIC DEEP DIVE (COFFS HARBOUR)
-- ============================================================================

-- 10.1: All Coffs Harbour students (in Supabase)
SELECT 
  vs.email,
  vs.full_name,
  vs.school_id,
  vs.school_name,
  vs.current_year_group,
  vs.student_group,
  vs.created_at,
  COUNT(ar.id) as activity_count
FROM vespa_students vs
LEFT JOIN activity_responses ar ON ar.student_email = vs.email
WHERE vs.school_name ILIKE '%coffs%' 
   OR vs.school_id IN (
     SELECT id FROM establishments WHERE name ILIKE '%coffs%'
   )
GROUP BY vs.email, vs.full_name, vs.school_id, vs.school_name, 
         vs.current_year_group, vs.student_group, vs.created_at
ORDER BY vs.email;

-- 10.2: Coffs Harbour establishment details
SELECT 
  e.id,
  e.name,
  e.knack_id,
  e.is_australian,
  e.use_standard_year,
  e.created_at,
  COUNT(vs.id) as current_student_count
FROM establishments e
LEFT JOIN vespa_students vs ON vs.school_id = e.id
WHERE e.name ILIKE '%coffs%'
GROUP BY e.id, e.name, e.knack_id, e.is_australian, e.use_standard_year, e.created_at;

-- ============================================================================
-- SUMMARY QUERY: DASHBOARD OVERVIEW
-- ============================================================================

SELECT 
  'Total Students' as metric,
  COUNT(*)::text as value
FROM vespa_students
UNION ALL
SELECT 
  'Orphaned Students (NULL school_id)',
  COUNT(*)::text
FROM vespa_students WHERE school_id IS NULL
UNION ALL
SELECT 
  'Students with HTML emails',
  COUNT(*)::text
FROM vespa_students WHERE email LIKE '%<a href%'
UNION ALL
SELECT 
  'Students missing full_name',
  COUNT(*)::text
FROM vespa_students WHERE full_name IS NULL OR full_name = ''
UNION ALL
SELECT 
  'Total Establishments',
  COUNT(*)::text
FROM establishments
UNION ALL
SELECT 
  'Activity Responses',
  COUNT(*)::text
FROM activity_responses
UNION ALL
SELECT 
  'Empty Response JSONs',
  COUNT(*)::text
FROM activity_responses WHERE responses = '{}'
UNION ALL
SELECT 
  'Completed Activities with Empty Responses',
  COUNT(*)::text
FROM activity_responses WHERE status = 'completed' AND responses = '{}';

-- ============================================================================
-- END OF DIAGNOSTIC QUERIES
-- ============================================================================



