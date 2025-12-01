-- V21: Restore start_deep_link_view_session function
-- V20 accidentally removed this function when updating complete_deep_link_view_session
-- This function is required by qr-validation-lambda to initiate view tracking

-- Drop existing function with explicit signature
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
BEGIN
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
        is_completed = false,
        session_end_at = NULL,
        actual_view_duration_seconds = NULL,
        completed_at = NULL
    RETURNING view_id INTO v_view_id;
    
    RETURN v_view_id;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION kshipra_core.start_deep_link_view_session(VARCHAR, UUID, INTEGER, VARCHAR, TEXT, VARCHAR, TEXT) TO kshipra_admin;

COMMENT ON FUNCTION kshipra_core.start_deep_link_view_session(VARCHAR, UUID, INTEGER, VARCHAR, TEXT, VARCHAR, TEXT) IS 
'Starts a new view session when user opens a deep link. Resets session if user revisits same campaign.';
