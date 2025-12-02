-- Check problem_mappings array in activities table

-- Step 1: Show activities with their problem_mappings
SELECT 
    id,
    name,
    vespa_category,
    level,
    problem_mappings,
    array_length(problem_mappings, 1) as problem_count
FROM activities
WHERE is_active = true
  AND problem_mappings IS NOT NULL
  AND array_length(problem_mappings, 1) > 0
ORDER BY vespa_category, name
LIMIT 20;

-- Step 2: Get ALL distinct problems across all activities
SELECT DISTINCT
    unnest(problem_mappings) as problem_text,
    COUNT(*) as activity_count
FROM activities
WHERE is_active = true
  AND problem_mappings IS NOT NULL
GROUP BY problem_text
ORDER BY problem_text;

-- Step 3: Show problems grouped by category
SELECT 
    vespa_category,
    unnest(problem_mappings) as problem,
    COUNT(*) as activity_count
FROM activities
WHERE is_active = true
  AND problem_mappings IS NOT NULL
GROUP BY vespa_category, problem
ORDER BY vespa_category, problem;

-- Step 4: Find activities for a specific problem (example)
-- Replace 'problem text here' with actual problem text from step 2
-- SELECT 
--     id,
--     name,
--     vespa_category,
--     level,
--     problem_mappings
-- FROM activities
-- WHERE is_active = true
--   AND 'I struggle to complete my homework on time' = ANY(problem_mappings)
-- ORDER BY vespa_category, level;

-- Step 5: Count total activities with/without problems
SELECT 
    COUNT(*) FILTER (WHERE problem_mappings IS NULL OR array_length(problem_mappings, 1) = 0 OR array_length(problem_mappings, 1) IS NULL) as no_problems,
    COUNT(*) FILTER (WHERE problem_mappings IS NOT NULL AND array_length(problem_mappings, 1) > 0) as has_problems,
    COUNT(*) as total_active
FROM activities
WHERE is_active = true;

