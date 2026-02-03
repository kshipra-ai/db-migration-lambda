-- V123: Fix complete_deep_link_view_session - Cast user_id to VARCHAR in qr_scans updates
-- The qr_scans table has user_id as UUID, but p_user_id parameter is VARCHAR

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
        RAISE EXCEPTION 'Campaign % not found', p_campaign_id;
    END IF;

    -- Mark the view session as completed if duration meets requirement
    IF p_actual_duration_seconds >= v_required_duration THEN
        v_is_completed := TRUE;
        v_points_awarded := v_reward_rate;

        -- Get the percentage allocations from partners.config
        SELECT 
            COALESCE((config->>'user_rewards_pct')::DECIMAL(5,2), 60.00),
            COALESCE((config->>'cashback_pct')::DECIMAL(5,2), 30.00),
            COALESCE((config->>'kshipra_commission_pct')::DECIMAL(5,2), 10.00)
        INTO 
            v_user_rewards_pct,
            v_cashback_pct,
            v_kshipra_commission_pct
        FROM kshipra_core.partners
        WHERE partner_id = v_partner_id;

        -- Calculate amounts
        v_user_rewards_cents := ROUND((v_scan_reward_points * v_user_rewards_pct / 100.0)::NUMERIC, 0)::INTEGER;
        v_cashback_cents := ROUND((v_scan_reward_points * v_cashback_pct / 100.0)::NUMERIC, 0)::INTEGER;
        v_kshipra_commission_cents := ROUND((v_scan_reward_points * v_kshipra_commission_pct / 100.0)::NUMERIC, 0)::INTEGER;

        -- Record the user rewards allocation
        INSERT INTO kshipra_core.kshipra_earnings (
            user_id,
            campaign_id,
            partner_id,
            amount_cents,
            earning_type,
            earned_at
        ) VALUES (
            p_user_id::UUID,
            p_campaign_id,
            v_partner_id,
            v_user_rewards_cents,
            'user_rewards',
            CURRENT_TIMESTAMP
        );

        -- Update user_deep_link_views to mark as completed
        UPDATE kshipra_core.user_deep_link_views
        SET 
            is_completed = TRUE,
            actual_duration_seconds = p_actual_duration_seconds,
            points_awarded = v_points_awarded
        WHERE udlv.user_id::VARCHAR = p_user_id
          AND udlv.campaign_id = p_campaign_id
          AND is_completed = FALSE;

        -- Update user's rewards_earned in user_profile
        UPDATE kshipra_core.user_profile up
        SET rewards_earned = COALESCE(rewards_earned, 0) + v_scan_reward_points
        WHERE up.user_id::VARCHAR = p_user_id;

        -- Insert reward distribution records
        INSERT INTO kshipra_core.reward_distribution (
            campaign_id,
            partner_id,
            user_rewards_cents,
            cashback_cents,
            kshipra_commission_cents,
            distribution_date
        ) VALUES (
            p_campaign_id,
            v_partner_id,
            v_user_rewards_cents,
            v_cashback_cents,
            v_kshipra_commission_cents,
            CURRENT_DATE
        ) ON CONFLICT (campaign_id, partner_id, distribution_date) 
        DO UPDATE SET
            user_rewards_cents = reward_distribution.user_rewards_cents + EXCLUDED.user_rewards_cents,
            cashback_cents = reward_distribution.cashback_cents + EXCLUDED.cashback_cents,
            kshipra_commission_cents = reward_distribution.kshipra_commission_cents + EXCLUDED.kshipra_commission_cents,
            updated_at = CURRENT_TIMESTAMP;

        -- Update the qr_scans table with actual points awarded (FIXED: Cast user_id to VARCHAR)
        UPDATE kshipra_core.qr_scans
        SET points_awarded = v_scan_reward_points
        WHERE user_id::VARCHAR = p_user_id 
          AND campaign_id = p_campaign_id::VARCHAR
          AND points_awarded = 0
          AND scanned_at >= CURRENT_DATE;
    ELSE
        -- View not completed - update scan record with 0 points (FIXED: Cast user_id to VARCHAR)
        UPDATE kshipra_core.qr_scans
        SET points_awarded = 0
        WHERE user_id::VARCHAR = p_user_id 
          AND campaign_id = p_campaign_id::VARCHAR
          AND scanned_at >= CURRENT_DATE;
    END IF;

    -- Get user's total points after update
    SELECT COALESCE(rewards_earned, 0) INTO v_total_points
    FROM kshipra_core.user_profile
    WHERE user_id::VARCHAR = p_user_id;

    -- Return the results
    RETURN QUERY SELECT 
        v_is_completed,
        v_points_awarded,
        v_user_rewards_cents,
        v_cashback_cents,
        v_total_points;
    
    -- Update view session completion status
    UPDATE kshipra_core.user_deep_link_views
    SET is_completed = v_is_completed
    WHERE user_id::VARCHAR = p_user_id AND campaign_id = p_campaign_id;
END;
$$ LANGUAGE plpgsql;
