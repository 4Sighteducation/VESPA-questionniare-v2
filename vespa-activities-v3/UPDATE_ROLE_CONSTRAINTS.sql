-- ============================================
-- Update Role Constraints for Legacy Roles
-- ============================================
-- Run this AFTER ADDITIVE_HYBRID_MIGRATION.sql
-- Adds: general_staff, head_of_department, parent
-- ============================================

-- Drop and recreate user_roles constraint
ALTER TABLE user_roles DROP CONSTRAINT IF EXISTS valid_role_type;

ALTER TABLE user_roles ADD CONSTRAINT valid_role_type CHECK (role_type IN (
  'tutor', 
  'staff_admin', 
  'head_of_year', 
  'subject_teacher', 
  'mentor', 
  'coordinator',
  'general_staff',
  'head_of_department',
  'parent'
));

-- Drop and recreate user_connections constraint
ALTER TABLE user_connections DROP CONSTRAINT IF EXISTS valid_connection_type;

ALTER TABLE user_connections ADD CONSTRAINT valid_connection_type CHECK (connection_type IN (
  'tutor',
  'head_of_year',
  'subject_teacher',
  'staff_admin',
  'mentor',
  'general_staff',
  'head_of_department',
  'parent'
));

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Role constraints updated!';
  RAISE NOTICE '   Added: general_staff, head_of_department, parent';
END $$;

