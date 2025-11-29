-- ============================================
-- Fix vespa_staff Missing Columns
-- ============================================
-- Adds school_id and school_name to vespa_staff
-- ============================================

-- Add missing columns
ALTER TABLE vespa_staff 
ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES establishments(id) ON DELETE SET NULL;

ALTER TABLE vespa_staff 
ADD COLUMN IF NOT EXISTS school_name VARCHAR(255);

-- Create index
CREATE INDEX IF NOT EXISTS idx_vespa_staff_school ON vespa_staff(school_id);

-- Verify
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'vespa_staff'
AND column_name IN ('school_id', 'school_name')
ORDER BY column_name;

-- Success
DO $$
BEGIN
  RAISE NOTICE '✅ Added school_id and school_name to vespa_staff';
END $$;

