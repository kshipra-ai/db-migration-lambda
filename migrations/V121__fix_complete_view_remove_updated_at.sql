-- V121: Fix complete_deep_link_view_session - Remove updated_at column reference from user_profile UPDATE
-- The user_profile table doesn't have an updated_at column, causing reward allocation to fail

DROP FUNCTION IF EXISTS kshipra_core.complete_deep_link_view_session(VARCHAR, UUID, INTEGER);

CREATE OR REPLACE FUNCTION kshipra_core.complete_deep_link_view_session(
    p_user_id VARCHAR(255),
    p_campaign_id UUID,
    p_actual_duration_seconds INTEGER
)
RETURNS TABLE(
    is_completed BOOLEAN,
    points_awarded INTEGER,
    user_rewards_points INTEGER,
    cashback_cents INTEGER,
    total_user_points INTEGER
) AS $$
DECLARE
    v_required_duration INTEGER;
    v_is_completed BOOLEAN := FALSE;
    v_reward_rate INTEGER;
    v_scan_reward_points INTEGER;
    v_points_awarded INTEGER := 0;
    v_partner_id UUID;
    v_total_points INTEGER := 0;
    
    -- Reward distribution variables
    v_user_rewards_pct DECIMAL(5,2);
    v_cashback_pct DECIMAL(5,2);
    v_kshipra_commission_pct DECIMAL(5,2);
    v_user_rewards_cents INTEGER := 0;
    v_cashback_cents INTEGER := 0;
    v_kshipra_commission_cents INTEGER := 0;
BEGIN
    -- Get campaign details and brand's configured scan_reward_points
    SELECT 
        c.min_view_duration_seconds,
        c.reward_rate,
        c.partner_id,
        COALESCE((p.config->>'scan_reward_points')::INTEGER, c.reward_rate) as scan_points
    INTO 
        v_required_duration,
        v_reward_rate,
        v_partner_id,
        v_scan_reward_points
    FROM kshipra_core.campaigns c
    LEFT JOIN kshipra_core.partners p ON c.partner_id = p.partner_id
    WHERE c.campaign_id = p_campaign_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Campaign not found';
    END IF;

    -- Check if view duration meets requirement
    IF p_actual_duration_seconds >= v_required_duration THEN
        v_is_completed := TRUE;
        v_points_awarded := v_scan_reward_points;

        -- Get active reward distribution configuration
        SELECT 
            user_rewards_percentage,
            cashback_percentage,
            kshipra_commission_percentage
        INTO 
            v_user_rewards_pct,
            v_cashback_pct,
            v_kshipra_commission_pct
        FROM kshipra_core.reward_distribution_config
        WHERE is_active = TRUE
        LIMIT 1;

        -- Use default distribution if no config found
        IF v_user_rewards_pct IS NULL THEN
            v_user_rewards_pct := 60.00;
            v_cashback_pct := 30.00;
            v_kshipra_commission_pct := 10.00;
        END IF;

        -- Calculate reward distribution (in cents/points)
        v_user_rewards_cents := ROUND(v_scan_reward_points * v_user_rewards_pct / 100);
        v_cashback_cents := ROUND(v_scan_reward_points * v_cashback_pct / 100);
        v_kshipra_commission_cents := ROUND(v_scan_reward_points * v_kshipra_commission_pct / 100);

        -- Update view session as completed
        UPDATE kshipra_core.user_deep_link_views udlv
        SET 
            completed_at = CURRENT_TIMESTAMP,
            is_completed = TRUE,
            updated_at = CURRENT_TIMESTAMP
        WHERE udlv.user_id::VARCHAR = p_user_id
          AND udlv.campaign_id = p_campaign_id
          AND udlv.is_completed = FALSE;

        -- Update user profile with distributed rewards (FIXED: removed updated_at reference)
        UPDATE kshipra_core.user_profile up
        SET 
            rewards_earned = up.rewards_earned + v_user_rewards_cents,
            cash_balance = up.cash_balance + (v_cashback_cents::DECIMAL / 100)
        WHERE up.user_id::VARCHAR = p_user_id;

        -- Record Kshipra's commission
        INSERT INTO kshipra_core.kshipra_earnings (
            user_id,
            campaign_id,
            source_type,
            total_reward_points,
            commission_points,
            commission_percentage,
            created_at
        ) VALUES (
            p_user_id::UUID,
            p_campaign_id,
            'scan_earn',
            v_scan_reward_points,
            v_kshipra_commission_cents,
            v_kshipra_commission_pct,
            CURRENT_TIMESTAMP
        );
        
        -- Update the qr_scans table with actual points awarded
        UPDATE kshipra_core.qr_scans
        SET points_awarded = v_scan_reward_points
        WHERE user_id = p_user_id 
          AND campaign_id = p_campaign_id::VARCHAR
          AND points_awarded = 0
          AND scanned_at >= CURRENT_DATE;
    ELSE
        -- View not completed - update scan record with 0 points
        UPDATE kshipra_core.qr_scans
        SET points_awarded = 0
        WHERE user_id = p_user_id 
          AND campaign_id = p_campaign_id::VARCHAR
          AND scanned_at >= CURRENT_DATE;
    END IF;

    -- Get user's total points after update
    SELECT COALESCE(rewards_earned, 0) INTO v_total_points
    FROM kshipra_core.user_profile
    WHERE user_id::VARCHAR = p_user_id;

    -- Update view record with completion details
    UPDATE kshipra_core.user_deep_link_views
    SET 
        session_end_at = CURRENT_TIMESTAMP,
        actual_view_duration_seconds = p_actual_duration_seconds,
        is_completed = v_is_completed,
        completed_at = CASE WHEN v_is_completed THEN CURRENT_TIMESTAMP ELSE NULL END
    WHERE user_id::VARCHAR = p_user_id AND campaign_id = p_campaign_id;
    
    RETURN QUERY SELECT v_is_completed, v_points_awarded, v_user_rewards_cents, v_cashback_cents, v_total_points;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION kshipra_core.complete_deep_link_view_session TO kshipra_admin;

COMMENT ON FUNCTION kshipra_core.complete_deep_link_view_session IS 
'Completes view session and updates qr_scans table with actual points awarded. Awards rewards with distribution split if duration requirement met. Fixed: removed updated_at column reference from user_profile UPDATE.';
