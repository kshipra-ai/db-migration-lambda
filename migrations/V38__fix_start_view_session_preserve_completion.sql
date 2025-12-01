-- V38: Fix start_deep_link_view_session to preserve is_completed status
-- When user scans QR again after completing a campaign, don't reset is_completed to false
-- This prevents already-viewed campaigns from becoming "unviewed" again

DROP FUNCTION IF EXISTS kshipra_core.start_deep_link_view_session(VARCHAR, UUID, INTEGER, VARCHAR, TEXT, VARCHAR, TEXT);

CREATE OR REPLACE FUNCTION kshipra_core.start_deep_link_view_session(
    p_user_id VARCHAR(255),
    p_campaign_id UUID,
    p_required_duration_seconds INTEGER,
    p_qr_code_id VARCHAR(255) DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_ip_address VARCHAR(45) DEFAULT NULL,
    p_scan_location TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_view_id UUID;
    v_existing_completed BOOLEAN;
BEGIN
    -- Check if this campaign was already completed
    SELECT is_completed INTO v_existing_completed
    FROM kshipra_core.user_deep_link_views
    WHERE user_id = p_user_id AND campaign_id = p_campaign_id;
    
    -- Insert or update view record
    INSERT INTO kshipra_core.user_deep_link_views (
        user_id,
        campaign_id,
        session_start_at,
        required_duration_seconds,
        qr_code_id,
        user_agent,
        ip_address,
        scan_location,
        is_completed
    ) VALUES (
        p_user_id,
        p_campaign_id,
        CURRENT_TIMESTAMP,
        p_required_duration_seconds,
        p_qr_code_id,
        p_user_agent,
        p_ip_address,
        p_scan_location,
        false
    )
    ON CONFLICT (user_id, campaign_id) DO UPDATE SET
        session_start_at = CURRENT_TIMESTAMP,
        required_duration_seconds = p_required_duration_seconds,
        -- CRITICAL: Don't reset is_completed if already true (preserves completion status)
        is_completed = CASE 
            WHEN kshipra_core.user_deep_link_views.is_completed THEN true
            ELSE false
        END,
        -- Only reset session_end and duration if not already completed
        session_end_at = CASE 
            WHEN kshipra_core.user_deep_link_views.is_completed THEN kshipra_core.user_deep_link_views.session_end_at
            ELSE NULL
        END,
        actual_view_duration_seconds = CASE 
            WHEN kshipra_core.user_deep_link_views.is_completed THEN kshipra_core.user_deep_link_views.actual_view_duration_seconds
            ELSE NULL
        END,
        completed_at = CASE 
            WHEN kshipra_core.user_deep_link_views.is_completed THEN kshipra_core.user_deep_link_views.completed_at
            ELSE NULL
        END
    RETURNING view_id INTO v_view_id;
    
    RETURN v_view_id;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION kshipra_core.start_deep_link_view_session(VARCHAR, UUID, INTEGER, VARCHAR, TEXT, VARCHAR, TEXT) TO kshipra_admin;

COMMENT ON FUNCTION kshipra_core.start_deep_link_view_session(VARCHAR, UUID, INTEGER, VARCHAR, TEXT, VARCHAR, TEXT) IS 
'Starts a new view session when user opens a campaign. Preserves is_completed status if campaign was already completed (for rotation without rewards).';
