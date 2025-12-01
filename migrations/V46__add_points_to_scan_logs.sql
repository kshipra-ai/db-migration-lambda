-- V46__add_points_to_scan_logs.sql
-- Adds points_redeemed column to redemption_scan_logs for audit trail and billing analytics

-- Add points_redeemed column to track value of each scan
ALTER TABLE kshipra_core.redemption_scan_logs 
ADD COLUMN IF NOT EXISTS points_redeemed INTEGER;

-- Add check constraint to ensure positive points
ALTER TABLE kshipra_core.redemption_scan_logs
ADD CONSTRAINT chk_scan_log_points_positive CHECK (points_redeemed IS NULL OR points_redeemed > 0);

-- Add index for analytics queries
CREATE INDEX IF NOT EXISTS idx_scan_logs_points ON kshipra_core.redemption_scan_logs(points_redeemed);

-- Comment
COMMENT ON COLUMN kshipra_core.redemption_scan_logs.points_redeemed IS 'Points value of the redemption for billing analytics and audit trail';

-- Migration complete
DO $$
BEGIN
    RAISE NOTICE 'Migration V46 completed: Added points_redeemed to redemption_scan_logs';
END $$;
