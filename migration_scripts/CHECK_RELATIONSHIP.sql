-- Check if foreign key relationship exists between student_activities and activities

-- 1. Check foreign key constraints (PostgreSQL correct syntax)
SELECT 
    tc.constraint_name, 
    tc.table_name, 
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_name='student_activities';

-- 2. Manual JOIN test - Does it work?
SELECT 
    sa.student_email,
    sa.activity_id,
    a.name as activity_name,
    a.vespa_category,
    sa.status
FROM student_activities sa
LEFT JOIN activities a ON a.id = sa.activity_id
WHERE sa.student_email = 'aramsey@vespa.academy'
LIMIT 5;

-- 3. Check if activity_id values are valid UUIDs
SELECT 
    student_email,
    activity_id,
    activity_id::text as activity_id_string,
    status
FROM student_activities
WHERE student_email = 'aramsey@vespa.academy';

