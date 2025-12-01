-- V82: Fix user_id and campaign_id types in kshipra_earnings insert

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

        -- Default to 50/25/25 if no active config found
        IF NOT FOUND THEN
            v_user_rewards_pct := 50.00;
            v_cashback_pct := 25.00;
            v_kshipra_commission_pct := 25.00;
        END IF;

        -- Calculate distributed amounts (points are in cents)
        v_user_rewards_cents := ROUND(v_scan_reward_points * v_user_rewards_pct / 100);
        v_cashback_cents := ROUND(v_scan_reward_points * v_cashback_pct / 100);
        v_kshipra_commission_cents := ROUND(v_scan_reward_points * v_kshipra_commission_pct / 100);

        -- Update view session as completed
        UPDATE kshipra_core.user_deep_link_views udlv
        SET 
            completed_at = CURRENT_TIMESTAMP,
            is_completed = TRUE
        WHERE udlv.user_id::VARCHAR = p_user_id
          AND udlv.campaign_id = p_campaign_id
          AND udlv.is_completed = FALSE;

        -- Update user profile with distributed rewards
        UPDATE kshipra_core.user_profile up
        SET 
            rewards_earned = up.rewards_earned + v_user_rewards_cents,
            cash_balance = up.cash_balance + (v_cashback_cents::DECIMAL / 100)
        WHERE up.user_id::VARCHAR = p_user_id;

        -- Record Kshipra's commission (user_id and campaign_id are VARCHAR)
        INSERT INTO kshipra_core.kshipra_earnings (
            user_id,
            campaign_id,
            source_type,
            total_reward_points,
            commission_points,
            commission_percentage,
            earned_at
        ) VALUES (
            p_user_id,
            p_campaign_id::VARCHAR,
            'scan_earn',
            v_scan_reward_points,
            v_kshipra_commission_cents,
            v_kshipra_commission_pct,
            CURRENT_TIMESTAMP
        );
    END IF;

    -- Get user's total rewards points
    SELECT COALESCE(up.rewards_earned, 0)
    INTO v_total_points
    FROM kshipra_core.user_profile up
    WHERE up.user_id::VARCHAR = p_user_id;

    -- Return results
    RETURN QUERY
    SELECT 
        v_is_completed,
        v_points_awarded,
        v_user_rewards_cents,
        v_cashback_cents,
        v_total_points;
END;
$$ LANGUAGE plpgsql;
