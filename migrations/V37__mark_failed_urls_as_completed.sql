-- V37: Mark failed URL views (duration=0) as completed to skip them in rotation
-- When a campaign URL fails to load, we call completeView with duration=0
-- This should mark it as "viewed" so the next scan shows a different campaign

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
    
    -- Special case: duration=0 means URL failed to load
    -- Mark as completed (to skip in rotation) but award 0 points
    IF p_actual_duration_seconds = 0 THEN
        UPDATE kshipra_core.user_deep_link_views
        SET 
            session_end_at = CURRENT_TIMESTAMP,
            actual_view_duration_seconds = 0,
            is_completed = true,  -- Mark as completed to skip in next scan
            completed_at = CURRENT_TIMESTAMP
        WHERE user_id = p_user_id AND campaign_id = p_campaign_id;
        
        RETURN QUERY SELECT true, 0;  -- Completed but no points
        RETURN;
    END IF;
    
    -- Check if duration requirement met
    v_is_completed := (p_actual_duration_seconds >= v_required_duration);
    
    -- If completing for the first time and duration met, award points
    -- BUT ONLY IF USER IS NOT A BRAND USER
    IF v_is_completed AND NOT COALESCE(v_already_completed, false) AND v_user_role != 'brand' THEN
        v_points_awarded := v_reward_rate;
        
        -- Award points to user (only regular users, not brands)
        UPDATE kshipra_core.user_profile
        SET rewards_earned = COALESCE(rewards_earned, 0) + v_points_awarded
        WHERE user_id = p_user_id;
        
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION kshipra_core.complete_deep_link_view_session TO kshipra_admin;

COMMENT ON FUNCTION kshipra_core.complete_deep_link_view_session IS 
'Completes view session. If duration=0 (URL failed), marks as completed with 0 points to skip in rotation. If duration met, awards rewards to regular users only (not brands). Returns completion status and points awarded';
