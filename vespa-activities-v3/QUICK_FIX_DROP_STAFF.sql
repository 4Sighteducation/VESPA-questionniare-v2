-- ============================================
-- Quick Fix: Drop vespa_staff to reset
-- ============================================
-- Run this, then run FUTURE_READY_SCHEMA.sql again

DROP TABLE IF EXISTS vespa_staff CASCADE;

SELECT '✅ Dropped vespa_staff table. Now run FUTURE_READY_SCHEMA.sql' as message;


