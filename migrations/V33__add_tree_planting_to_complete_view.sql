-- V33: Add tree planting logic to complete_deep_link_view_session
-- When points are awarded via QR scanning, automatically update trees_planted count

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
    v_current_points INTEGER;
    v_points_per_tree INTEGER;
    v_new_tree_count INTEGER;
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
        
        -- Award points to user (only regular users, not brands)
        UPDATE kshipra_core.user_profile
        SET rewards_earned = COALESCE(rewards_earned, 0) + v_points_awarded
        WHERE user_id = p_user_id
        RETURNING rewards_earned, COALESCE(points_for_next_tree, 50) 
        INTO v_current_points, v_points_per_tree;
        
        -- Calculate how many trees user should have based on total points
        v_new_tree_count := FLOOR(v_current_points / v_points_per_tree);
        
        -- Update trees_planted count
        UPDATE kshipra_core.user_profile
        SET trees_planted = v_new_tree_count
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
'Completes view session, awards rewards if duration requirement met (first time only) ONLY TO REGULAR USERS (not brands), automatically updates trees_planted count based on points_for_next_tree threshold, returns completion status and points awarded';
