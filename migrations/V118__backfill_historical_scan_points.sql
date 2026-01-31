-- V118: Mark historical scan records as non-rewards method
-- This addresses scan records created before V117 migration that show 0 points
-- Instead of guessing reward values, mark them as non-reward activities

-- Strategy: Mark completed scans as non-rewards method (-1) to distinguish from failed scans (0)

DO $$
DECLARE
    r RECORD;
    v_updated_count INTEGER := 0;
BEGIN
    RAISE NOTICE 'V118: Starting historical scan classification...';
    
    -- Update scan records that have completed view sessions but show 0 points
    -- Mark them as non-rewards method (-1) instead of failed scans (0)
    FOR r IN 
        SELECT DISTINCT
            qs.scan_id,
            qs.user_id,
            qs.campaign_id,
            qs.scanned_at
        FROM kshipra_core.qr_scans qs
        INNER JOIN kshipra_core.user_deep_link_views udlv ON (
            udlv.user_id::TEXT = qs.user_id::TEXT 
            AND udlv.campaign_id::TEXT = qs.campaign_id::TEXT
            AND udlv.is_completed = TRUE
            AND DATE(udlv.completed_at) = DATE(qs.scanned_at)
        )
        WHERE qs.points_awarded = 0  -- Only scans showing 0 points
          AND qs.scanned_at < CURRENT_DATE  -- Historical scans only
        ORDER BY qs.scanned_at
    LOOP
        -- Update the scan record to mark as non-rewards method
        UPDATE kshipra_core.qr_scans 
        SET points_awarded = -1  -- -1 indicates non-rewards method (completed but no points system)
        WHERE scan_id = r.scan_id;
        
        v_updated_count := v_updated_count + 1;
        
        -- Log progress every 100 updates
        IF v_updated_count % 100 = 0 THEN
            RAISE NOTICE 'V118: Updated % scan records so far...', v_updated_count;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'V118: Classification complete. Updated % historical scan records as non-rewards method.', v_updated_count;
    
    -- Verify results
    SELECT COUNT(*) INTO v_updated_count
    FROM kshipra_core.qr_scans qs
    INNER JOIN kshipra_core.user_deep_link_views udlv ON (
        udlv.user_id::TEXT = qs.user_id::TEXT 
        AND udlv.campaign_id::TEXT = qs.campaign_id::TEXT
        AND udlv.is_completed = TRUE
        AND DATE(udlv.completed_at) = DATE(qs.scanned_at)
    )
    WHERE qs.points_awarded = 0
      AND qs.scanned_at < CURRENT_DATE;
      
    IF v_updated_count > 0 THEN
        RAISE WARNING 'V118: % scan records still show 0 points despite completed views. These may be edge cases requiring manual review.', v_updated_count;
    ELSE
        RAISE NOTICE 'V118: All historical scans with completed views now classified correctly!';
    END IF;
    
END $$;

-- Update column documentation
COMMENT ON COLUMN kshipra_core.qr_scans.points_awarded IS 
'Points awarded for this scan: positive values = actual points earned, 0 = incomplete/failed view, -1 = completed non-rewards method (historical scans before rewards system).';