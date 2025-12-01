-- FIX: activity_history table RLS policy
-- The 401 error happens because staff can't insert into activity_history

-- Step 1: Check current RLS status
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'activity_history';

-- Step 2: Drop existing restrictive policies
DROP POLICY IF EXISTS "activity_history_select_policy" ON activity_history;
DROP POLICY IF EXISTS "activity_history_insert_policy" ON activity_history;

-- Step 3: Create permissive INSERT policy for authenticated users
-- This allows anyone with a valid session to log activity history
CREATE POLICY "activity_history_insert_policy" 
ON activity_history
FOR INSERT
TO authenticated
WITH CHECK (true);  -- Allow all authenticated inserts

-- Step 4: Create SELECT policy (read own school's history)
CREATE POLICY "activity_history_select_policy" 
ON activity_history
FOR SELECT
TO authenticated
USING (
  -- Can read if triggered by you OR if you're staff at the student's school
  triggered_by_email = auth.jwt() ->> 'email'
  OR
  EXISTS (
    SELECT 1 FROM vespa_students vs
    WHERE vs.email = activity_history.student_email
    AND vs.school_id IN (
      SELECT school_id FROM vespa_staff
      WHERE email = auth.jwt() ->> 'email'
    )
  )
);

-- Step 5: Verify policies are in place
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'activity_history';

-- Step 6: Test insert (should work now)
INSERT INTO activity_history (
    student_email,
    activity_id,
    action,
    triggered_by,
    triggered_by_email,
    metadata
) VALUES (
    'aramsey@vespa.academy',
    'b8c9b21a-b88d-412b-8217-e33710e0af78',
    'test_remove',
    'staff',
    'tut7@vespa.academy',
    '{"test": true}'::jsonb
) RETURNING *;

