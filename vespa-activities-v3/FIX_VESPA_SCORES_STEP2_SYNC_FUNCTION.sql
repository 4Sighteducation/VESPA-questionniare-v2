-- ============================================================================
-- STEP 2: Create function to sync latest scores to vespa_students
-- ============================================================================
-- Purpose: Populate vespa_students.latest_vespa_scores from vespa_scores table
-- This enables the student activities app to display real scores
-- ============================================================================

-- ============================================================================
-- FUNCTION: sync_latest_vespa_scores_to_student
-- ============================================================================
-- Syncs the latest VESPA score for a specific student (by email)
-- to their vespa_students.latest_vespa_scores JSONB field
--
-- MULTI-YEAR AWARE: Handles students across multiple academic years
-- Priority: 1) Current academic year scores, 2) Most recent scores

CREATE OR REPLACE FUNCTION sync_latest_vespa_scores_to_student(
    p_student_email TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_latest_scores JSONB;
    v_current_academic_year TEXT;
    v_student_uuid UUID;
    v_rows_updated INTEGER;
BEGIN
    -- Get student's current academic year from vespa_students (if exists)
    SELECT current_academic_year INTO v_current_academic_year
    FROM vespa_students
    WHERE email = p_student_email;
    
    -- Get latest VESPA scores with multi-year support
    -- Strategy: Try current academic year first, then fall back to absolute latest
    
    IF v_current_academic_year IS NOT NULL THEN
        -- Try to get scores from current academic year first
        SELECT jsonb_build_object(
            'cycle', vsc.cycle,
            'academic_year', vsc.academic_year,
            'vision', vsc.vision,
            'effort', vsc.effort,
            'systems', vsc.systems,
            'practice', vsc.practice,
            'attitude', vsc.attitude,
            'overall', vsc.overall,
            'completion_date', vsc.completion_date,
            'synced_at', NOW()
        )
        INTO v_latest_scores
        FROM vespa_scores vsc
        INNER JOIN students s ON s.id = vsc.student_id
        WHERE s.email = p_student_email
          AND vsc.academic_year = v_current_academic_year
        ORDER BY vsc.completion_date DESC, vsc.cycle DESC
        LIMIT 1;
        
        -- Log what we found
        IF v_latest_scores IS NOT NULL THEN
            RAISE NOTICE 'Found scores for % in current academic year %', 
                p_student_email, v_current_academic_year;
        ELSE
            RAISE NOTICE 'No scores in current year % for %, trying all years...', 
                v_current_academic_year, p_student_email;
        END IF;
    END IF;
    
    -- If no scores in current academic year (or no current year set), get absolute latest
    IF v_latest_scores IS NULL THEN
        SELECT jsonb_build_object(
            'cycle', vsc.cycle,
            'academic_year', vsc.academic_year,
            'vision', vsc.vision,
            'effort', vsc.effort,
            'systems', vsc.systems,
            'practice', vsc.practice,
            'attitude', vsc.attitude,
            'overall', vsc.overall,
            'completion_date', vsc.completion_date,
            'synced_at', NOW(),
            'note', 'From previous academic year'
        )
        INTO v_latest_scores
        FROM vespa_scores vsc
        INNER JOIN students s ON s.id = vsc.student_id
        WHERE s.email = p_student_email
        ORDER BY vsc.completion_date DESC, vsc.cycle DESC
        LIMIT 1;
        
        IF v_latest_scores IS NOT NULL THEN
            RAISE NOTICE 'Using previous academic year scores for %', p_student_email;
        END IF;
    END IF;
    
    IF v_latest_scores IS NULL THEN
        RAISE NOTICE 'No VESPA scores found for student: %', p_student_email;
        RETURN NULL;
    END IF;
    
    -- Update or insert into vespa_students
    INSERT INTO vespa_students (
        email,
        latest_vespa_scores,
        updated_at
    )
    VALUES (
        p_student_email,
        v_latest_scores,
        NOW()
    )
    ON CONFLICT (email) 
    DO UPDATE SET
        latest_vespa_scores = EXCLUDED.latest_vespa_scores,
        updated_at = NOW();
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    RAISE NOTICE 'Updated latest_vespa_scores for %: cycle %, year %', 
        p_student_email,
        v_latest_scores->>'cycle',
        v_latest_scores->>'academic_year';
    
    RETURN v_latest_scores;
END;
$$;

-- ============================================================================
-- FUNCTION: sync_all_vespa_scores
-- ============================================================================
-- Syncs ALL students' latest scores to vespa_students table
-- Run this for initial population
--
-- MULTI-YEAR AWARE: For each student, syncs scores from their current academic year
-- (if they have scores in that year), otherwise uses absolute latest scores

CREATE OR REPLACE FUNCTION sync_all_vespa_scores()
RETURNS TABLE (
    student_email TEXT,
    academic_year_used TEXT,
    cycle_synced INTEGER,
    scores_synced BOOLEAN,
    scores JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH student_current_years AS (
        -- Get each student's current academic year (if known)
        SELECT 
            vs.email,
            vs.current_academic_year
        FROM vespa_students vs
        WHERE vs.email IS NOT NULL
    ),
    current_year_scores AS (
        -- Try to get scores from current academic year
        SELECT DISTINCT ON (s.email)
            s.email,
            vsc.cycle,
            vsc.academic_year,
            vsc.vision,
            vsc.effort,
            vsc.systems,
            vsc.practice,
            vsc.attitude,
            vsc.overall,
            vsc.completion_date,
            'current_year' as score_source
        FROM students s
        INNER JOIN vespa_scores vsc ON vsc.student_id = s.id
        INNER JOIN student_current_years scy ON scy.email = s.email
        WHERE s.email IS NOT NULL 
          AND s.email != ''
          AND vsc.academic_year = scy.current_academic_year
        ORDER BY s.email, vsc.completion_date DESC, vsc.cycle DESC
    ),
    all_latest_scores AS (
        -- Get absolute latest scores (fallback for students without current year scores)
        SELECT DISTINCT ON (s.email)
            s.email,
            vsc.cycle,
            vsc.academic_year,
            vsc.vision,
            vsc.effort,
            vsc.systems,
            vsc.practice,
            vsc.attitude,
            vsc.overall,
            vsc.completion_date,
            'latest_any_year' as score_source
        FROM students s
        INNER JOIN vespa_scores vsc ON vsc.student_id = s.id
        WHERE s.email IS NOT NULL 
          AND s.email != ''
          AND s.email NOT IN (SELECT cys.email FROM current_year_scores cys)  -- Qualify with alias
        ORDER BY s.email, vsc.completion_date DESC, vsc.cycle DESC
    ),
    combined_scores AS (
        -- Combine both approaches: current year first, then fallback
        SELECT * FROM current_year_scores
        UNION ALL
        SELECT * FROM all_latest_scores
    ),
    sync_updates AS (
        INSERT INTO vespa_students (
            email,
            latest_vespa_scores,
            updated_at
        )
        SELECT 
            cs.email,
            jsonb_build_object(
                'cycle', cs.cycle,
                'academic_year', cs.academic_year,
                'vision', cs.vision,
                'effort', cs.effort,
                'systems', cs.systems,
                'practice', cs.practice,
                'attitude', cs.attitude,
                'overall', cs.overall,
                'completion_date', cs.completion_date,
                'source', cs.score_source,
                'synced_at', NOW()
            ) as scores,
            NOW()
        FROM combined_scores cs
        ON CONFLICT (email) 
        DO UPDATE SET
            latest_vespa_scores = EXCLUDED.latest_vespa_scores,
            updated_at = NOW()
        RETURNING 
            vespa_students.email::TEXT,
            (vespa_students.latest_vespa_scores->>'academic_year')::TEXT as year_used,
            (vespa_students.latest_vespa_scores->>'cycle')::INTEGER as cycle_used,
            TRUE as synced,
            vespa_students.latest_vespa_scores
    )
    SELECT * FROM sync_updates;
END;
$$;

-- ============================================================================
-- FUNCTION: get_student_vespa_scores
-- ============================================================================
-- Convenient function to get a student's latest VESPA scores
-- Tries cache first, then queries vespa_scores if needed

CREATE OR REPLACE FUNCTION get_student_vespa_scores(
    p_student_email TEXT,
    p_force_refresh BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_cached_scores JSONB;
    v_fresh_scores JSONB;
BEGIN
    -- Check cache first (unless force refresh)
    IF NOT p_force_refresh THEN
        SELECT latest_vespa_scores INTO v_cached_scores
        FROM vespa_students
        WHERE email = p_student_email;
        
        IF v_cached_scores IS NOT NULL THEN
            RETURN v_cached_scores;
        END IF;
    END IF;
    
    -- Cache miss or force refresh - sync and return
    SELECT sync_latest_vespa_scores_to_student(p_student_email) INTO v_fresh_scores;
    
    RETURN v_fresh_scores;
END;
$$;

-- ============================================================================
-- TEST THE FUNCTIONS
-- ============================================================================

-- Test sync for specific student
SELECT sync_latest_vespa_scores_to_student('aramsey@vespa.academy');

-- Test get function
SELECT get_student_vespa_scores('aramsey@vespa.academy', FALSE);

-- Check if it worked
SELECT 
    email,
    full_name,
    latest_vespa_scores,
    latest_vespa_scores->>'vision' as vision,
    latest_vespa_scores->>'overall' as overall,
    latest_vespa_scores->>'cycle' as cycle
FROM vespa_students
WHERE email = 'aramsey@vespa.academy';

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant execute to anon (for student activities app)
GRANT EXECUTE ON FUNCTION sync_latest_vespa_scores_to_student(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION sync_all_vespa_scores() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_student_vespa_scores(TEXT, BOOLEAN) TO anon, authenticated;

-- ============================================================================
-- SUCCESS CRITERIA
-- ============================================================================
-- ✓ Functions created successfully
-- ✓ Test student has latest_vespa_scores populated
-- ✓ JSONB format matches expected structure
-- ✓ Ready to run bulk sync: SELECT * FROM sync_all_vespa_scores();
-- ============================================================================

