-- ⚠️ REQUIRED: Fix status constraint to allow 'removed'
-- This MUST be run for activity removal to work while preserving data!

-- Step 1: Check current constraint
SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conname = 'valid_activity_response_status';

-- Step 2: Drop old constraint
ALTER TABLE activity_responses 
DROP CONSTRAINT IF EXISTS valid_activity_response_status;

-- Step 3: Add new constraint with 'removed' included
ALTER TABLE activity_responses
ADD CONSTRAINT valid_activity_response_status
CHECK (status IN ('assigned', 'in_progress', 'completed', 'removed'));

-- Step 4: Verify new constraint
SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conname = 'valid_activity_response_status';

-- Step 5: Test it works - mark an activity as removed
UPDATE activity_responses
SET status = 'removed', updated_at = NOW()
WHERE student_email = 'aramsey@vespa.academy'
  AND activity_id = '49f3cd85-80f6-492b-8bff-142a74c7eb3e'
  AND cycle_number = 1
RETURNING id, status, student_email, activity_id;

-- Step 6: Verify RPC function filters it correctly
SELECT COUNT(*) as active_count
FROM get_student_activity_responses(
  'aramsey@vespa.academy',
  'tut7@vespa.academy',
  'b4bbffc9-7fb6-415a-9a8a-49648995f6b3'
);
-- Should be 62 now (not 63) because removed activities are filtered

-- Step 7: Check removed activities (for reporting)
SELECT 
    a.name,
    ar.status,
    ar.completed_at,
    ar.responses IS NOT NULL as has_responses
FROM activity_responses ar
JOIN activities a ON a.id = ar.activity_id
WHERE ar.student_email = 'aramsey@vespa.academy'
  AND ar.status = 'removed';

