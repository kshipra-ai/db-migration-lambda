-- V119: Emergency rollback of V118 historical scan classification
-- Restore points_awarded = -1 back to 0 to fix missing earning history
-- This is a temporary fix until auth-lambda deployment is verified

DO $$
DECLARE
    r RECORD;
    v_updated_count INTEGER := 0;
BEGIN
    RAISE NOTICE 'V119: Rolling back V118 scan classification changes...';
    
    -- Update all scan records with points_awarded = -1 back to 0
    UPDATE kshipra_core.qr_scans 
    SET points_awarded = 0
    WHERE points_awarded = -1;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    RAISE NOTICE 'V119: Rollback complete. Restored % scan records from -1 back to 0.', v_updated_count;
    
END $$;

-- Update column documentation
COMMENT ON COLUMN kshipra_core.qr_scans.points_awarded IS 
'Points awarded for this scan: positive values = actual points earned, 0 = incomplete/failed view or non-rewards method (temporary rollback from V118).';