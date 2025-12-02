-- Check activities table schema for problem fields

-- Step 1: Get all columns in activities table
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'activities'
ORDER BY ordinal_position;

-- Step 2: Check what distinct problems exist
SELECT DISTINCT
    problem,
    COUNT(*) as activity_count
FROM activities
WHERE is_active = true
  AND problem IS NOT NULL
  AND problem != ''
GROUP BY problem
ORDER BY problem;

-- Step 3: Show sample activities with their problems
SELECT 
    id,
    name,
    vespa_category,
    level,
    problem
FROM activities
WHERE is_active = true
  AND problem IS NOT NULL
  AND problem != ''
ORDER BY vespa_category, problem
LIMIT 20;

-- Step 4: Count activities by category and problem
SELECT 
    vespa_category,
    problem,
    COUNT(*) as count
FROM activities
WHERE is_active = true
  AND problem IS NOT NULL
GROUP BY vespa_category, problem
ORDER BY vespa_category, problem;

-- Step 5: Check if there are activities without problems
SELECT 
    COUNT(*) FILTER (WHERE problem IS NULL OR problem = '') as without_problem,
    COUNT(*) FILTER (WHERE problem IS NOT NULL AND problem != '') as with_problem,
    COUNT(*) as total
FROM activities
WHERE is_active = true;

