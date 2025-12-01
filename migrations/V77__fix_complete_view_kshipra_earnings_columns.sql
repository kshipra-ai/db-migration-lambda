-- V77: Fix complete_deep_link_view_session to match V75 kshipra_earnings table schema
-- Previous version used wrong column names (user_email, earning_type, amount_cents, amount_dollars, description)
-- Correct columns are: total_reward_points, commission_points, commission_percentage

DROP FUNCTION IF EXISTS kshipra_core.complete_deep_link_view_session(VARCHAR, UUID, INTEGER);

CREATE OR REPLACE FUNCTION kshipra_core.complete_deep_link_view_session(
    p_user_id VARCHAR(255),
    p_campaign_id UUID,
    p_actual_duration_seconds INTEGER
)
RETURNS TABLE(
    is_completed BOOLEAN,
    points_awarded INTEGER
) AS $$
DECLARE
    v_required_duration INTEGER;
    v_is_completed BOOLEAN;
    v_reward_rate INTEGER;
    v_points_awarded INTEGER := 0;
    v_already_completed BOOLEAN;
    v_user_role VARCHAR(50);
    v_user_rewards_pct NUMERIC;
    v_cashback_pct NUMERIC;
    v_kshipra_commission_pct NUMERIC;
    v_user_rewards_cents INTEGER;
    v_cashback_cents INTEGER;
    v_kshipra_commission_cents INTEGER;
    v_cashback_dollars NUMERIC;
BEGIN
    -- Get user role first - brand users should NOT earn rewards
    SELECT role INTO v_user_role
    FROM kshipra_core.user_profile
    WHERE user_id = p_user_id;
    
    -- Get required duration, reward rate, and completion status
    SELECT 
        udlv.required_duration_seconds,
        c.reward_rate,
        udlv.is_completed
    INTO 
        v_required_duration,
        v_reward_rate,
        v_already_completed
    FROM kshipra_core.user_deep_link_views udlv
    INNER JOIN kshipra_core.campaigns c ON udlv.campaign_id = c.campaign_id
    WHERE udlv.user_id = p_user_id AND udlv.campaign_id = p_campaign_id;
    
    IF v_required_duration IS NULL THEN
        -- View session not found
        RETURN QUERY SELECT false, 0;
        RETURN;
    END IF;
    
    -- Check if duration requirement met
    v_is_completed := (p_actual_duration_seconds >= v_required_duration);
    
    -- If completing for the first time and duration met, award points
    -- BUT ONLY IF USER IS NOT A BRAND USER
    IF v_is_completed AND NOT COALESCE(v_already_completed, false) AND v_user_role != 'brand' THEN
        v_points_awarded := v_reward_rate;
        
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
        WHERE is_active = true
        ORDER BY created_at DESC
        LIMIT 1;
        
        -- Use defaults if no config found (50/25/25)
        IF v_user_rewards_pct IS NULL THEN
            v_user_rewards_pct := 50.0;
            v_cashback_pct := 25.0;
            v_kshipra_commission_pct := 25.0;
        END IF;
        
        -- Calculate distribution (points represent cents)
        v_user_rewards_cents := FLOOR(v_points_awarded * v_user_rewards_pct / 100.0);
        v_cashback_cents := FLOOR(v_points_awarded * v_cashback_pct / 100.0);
        v_kshipra_commission_cents := v_points_awarded - v_user_rewards_cents - v_cashback_cents;
        
        v_cashback_dollars := v_cashback_cents::NUMERIC / 100.0;
        
        -- Award distributed rewards to user
        UPDATE kshipra_core.user_profile
        SET 
            rewards_earned = COALESCE(rewards_earned, 0) + v_user_rewards_cents,
            cash_balance = COALESCE(cash_balance, 0) + v_cashback_dollars
        WHERE user_id = p_user_id;
        
        -- Record Kshipra commission
        INSERT INTO kshipra_core.kshipra_earnings (
            user_id,
            campaign_id,
            source_type,
            total_reward_points,
            commission_points,
            commission_percentage
        ) VALUES (
            p_user_id,
            p_campaign_id::VARCHAR,
            'campaign_reward',
            v_points_awarded,
            v_kshipra_commission_cents,
            v_kshipra_commission_pct
        );
        
        -- Update campaign stats
        UPDATE kshipra_core.campaigns
        SET total_points_awarded = COALESCE(total_points_awarded, 0) + v_points_awarded
        WHERE campaign_id = p_campaign_id;
    END IF;
    
    -- Update view record
    UPDATE kshipra_core.user_deep_link_views
    SET 
        session_end_at = CURRENT_TIMESTAMP,
        actual_view_duration_seconds = p_actual_duration_seconds,
        is_completed = v_is_completed,
        completed_at = CASE WHEN v_is_completed THEN CURRENT_TIMESTAMP ELSE NULL END
    WHERE user_id = p_user_id AND campaign_id = p_campaign_id;
    
    RETURN QUERY SELECT v_is_completed, v_points_awarded;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION kshipra_core.complete_deep_link_view_session TO kshipra_admin;

COMMENT ON FUNCTION kshipra_core.complete_deep_link_view_session IS 
'Completes view session and distributes rewards according to configured percentages: user rewards, cashback, and Kshipra commission. Only awards points to regular users (not brand users) who meet duration requirement.';
