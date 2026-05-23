-- V171: Fix start_deep_link_view_session to update qr_code_id on conflict.
-- Previously ON CONFLICT preserved the old qr_code_id, so rescanning a location QR
-- after completing a campaign left qr_code_id stale/null, causing business share to
-- always be $0 (businessOwnerForUser join on location_qr_codes fails with null/wrong id).

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
        session_start_at       = CURRENT_TIMESTAMP,
        required_duration_seconds = p_required_duration_seconds,
        -- Update qr_code_id when a new scan provides one; keep existing value otherwise.
        qr_code_id             = COALESCE(EXCLUDED.qr_code_id, kshipra_core.user_deep_link_views.qr_code_id),
        -- Preserve completion status so already-viewed campaigns don't reset.
        is_completed           = CASE
                                     WHEN kshipra_core.user_deep_link_views.is_completed THEN true
                                     ELSE false
                                 END,
        session_end_at         = CASE
                                     WHEN kshipra_core.user_deep_link_views.is_completed THEN kshipra_core.user_deep_link_views.session_end_at
                                     ELSE NULL
                                 END,
        actual_view_duration_seconds = CASE
                                     WHEN kshipra_core.user_deep_link_views.is_completed THEN kshipra_core.user_deep_link_views.actual_view_duration_seconds
                                     ELSE NULL
                                 END,
        completed_at           = CASE
                                     WHEN kshipra_core.user_deep_link_views.is_completed THEN kshipra_core.user_deep_link_views.completed_at
                                     ELSE NULL
                                 END
    RETURNING view_id INTO v_view_id;

    RETURN v_view_id;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION kshipra_core.start_deep_link_view_session(VARCHAR, UUID, INTEGER, VARCHAR, TEXT, VARCHAR, TEXT) TO kshipra_admin;
