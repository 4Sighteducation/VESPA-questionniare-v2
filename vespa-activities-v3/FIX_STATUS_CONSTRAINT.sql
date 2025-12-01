-- FIX: Add 'removed' to valid status constraint
-- OR use DELETE instead of UPDATE to 'removed' status

-- Option 1: Check current constraint definition
SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conname = 'valid_activity_response_status';

-- Option 2A: Drop and recreate with 'removed' included
ALTER TABLE activity_responses 
DROP CONSTRAINT IF EXISTS valid_activity_response_status;

ALTER TABLE activity_responses
ADD CONSTRAINT valid_activity_response_status
CHECK (status IN ('assigned', 'in_progress', 'completed', 'removed'));

-- Option 2B: Or just use DELETE in code (simpler!)
-- The code now uses DELETE instead of UPDATE to 'removed'
-- So you don't need to change the constraint

-- Test deletion works (replace with real IDs)
DELETE FROM activity_responses
WHERE student_email = 'aramsey@vespa.academy'
  AND activity_id = '49f3cd85-80f6-492b-8bff-142a74c7eb3e'
  AND cycle_number = 1
RETURNING *;

