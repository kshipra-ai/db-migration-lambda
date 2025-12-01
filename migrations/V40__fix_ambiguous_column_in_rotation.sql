-- V40: Fix ambiguous column reference in V39 rotation query
-- The 'campaign_id' column reference was ambiguous in the last_campaign_position CTE

DROP FUNCTION IF EXISTS kshipra_core.get_next_unviewed_campaign(VARCHAR);

CREATE OR REPLACE FUNCTION kshipra_core.get_next_unviewed_campaign(
    p_user_id VARCHAR(255)
)
RETURNS TABLE (
    campaign_id UUID,
    landing_url VARCHAR(2048),
    campaign_name VARCHAR(255),
    campaign_description TEXT,
    min_view_duration_seconds INTEGER,
    reward_rate INTEGER,
    partner_brand VARCHAR(255)
) AS $$
DECLARE
    v_has_unviewed BOOLEAN;
    v_last_viewed_campaign_id UUID;
BEGIN
    -- Check if user has any unviewed campaigns
    SELECT EXISTS (
        SELECT 1
        FROM kshipra_core.campaigns c
        LEFT JOIN kshipra_core.user_deep_link_views udlv 
            ON c.campaign_id = udlv.campaign_id 
            AND udlv.user_id = p_user_id 
            AND udlv.is_completed = true
        WHERE 
            c.is_active = true
            AND c.landing_url IS NOT NULL
            AND (c.start_date IS NULL OR c.start_date <= CURRENT_TIMESTAMP)
            AND (c.end_date IS NULL OR c.end_date >= CURRENT_TIMESTAMP)
            AND udlv.view_id IS NULL  -- Not yet completed
    ) INTO v_has_unviewed;
    
    -- If user has viewed all campaigns, rotate to next one after most recently viewed
    IF NOT v_has_unviewed THEN
        -- Get the most recently viewed campaign
        SELECT udlv.campaign_id INTO v_last_viewed_campaign_id
        FROM kshipra_core.user_deep_link_views udlv
        WHERE udlv.user_id = p_user_id
        ORDER BY udlv.session_start_at DESC
        LIMIT 1;
        
        -- Return the next campaign after the last viewed one (circular rotation)
        RETURN QUERY
        WITH all_campaigns AS (
            SELECT 
                c.campaign_id as camp_id,
                c.landing_url,
                c.campaign_name,
                c.campaign_description,
                COALESCE(c.min_view_duration_seconds, 10) as min_view_duration_seconds,
                c.reward_rate,
                p.brand_name as partner_brand,
                c.created_at,
                ROW_NUMBER() OVER (ORDER BY c.created_at ASC) as row_num
            FROM kshipra_core.campaigns c
            INNER JOIN kshipra_core.partners p ON c.partner_id = p.partner_id
            WHERE 
                c.is_active = true
                AND p.is_active = true
                AND c.landing_url IS NOT NULL
                AND (c.start_date IS NULL OR c.start_date <= CURRENT_TIMESTAMP)
                AND (c.end_date IS NULL OR c.end_date >= CURRENT_TIMESTAMP)
        ),
        last_campaign_position AS (
            SELECT row_num
            FROM all_campaigns
            WHERE camp_id = v_last_viewed_campaign_id  -- FIX: Use camp_id alias
        )
        SELECT 
            ac.camp_id,  -- FIX: Use camp_id alias
            ac.landing_url,
            ac.campaign_name,
            ac.campaign_description,
            ac.min_view_duration_seconds,
            ac.reward_rate,
            ac.partner_brand
        FROM all_campaigns ac
        WHERE ac.row_num = (
            SELECT CASE 
                WHEN lcp.row_num >= (SELECT MAX(row_num) FROM all_campaigns) THEN 1  -- Wrap to first
                ELSE lcp.row_num + 1  -- Next campaign
            END
            FROM last_campaign_position lcp
        )
        UNION ALL
        -- Fallback: if no last viewed found, return first campaign
        SELECT 
            ac.camp_id,  -- FIX: Use camp_id alias
            ac.landing_url,
            ac.campaign_name,
            ac.campaign_description,
            ac.min_view_duration_seconds,
            ac.reward_rate,
            ac.partner_brand
        FROM all_campaigns ac
        WHERE ac.row_num = 1
        AND NOT EXISTS (SELECT 1 FROM last_campaign_position)
        LIMIT 1;
    ELSE
        -- Return next unviewed campaign in order
        RETURN QUERY
        SELECT 
            c.campaign_id,
            c.landing_url,
            c.campaign_name,
            c.campaign_description,
            COALESCE(c.min_view_duration_seconds, 10) as min_view_duration_seconds,
            c.reward_rate,
            p.brand_name as partner_brand
        FROM kshipra_core.campaigns c
        INNER JOIN kshipra_core.partners p ON c.partner_id = p.partner_id
        LEFT JOIN kshipra_core.user_deep_link_views udlv 
            ON c.campaign_id = udlv.campaign_id 
            AND udlv.user_id = p_user_id 
            AND udlv.is_completed = true
        WHERE 
            c.is_active = true
            AND p.is_active = true
            AND c.landing_url IS NOT NULL
            AND (c.start_date IS NULL OR c.start_date <= CURRENT_TIMESTAMP)
            AND (c.end_date IS NULL OR c.end_date >= CURRENT_TIMESTAMP)
            AND udlv.view_id IS NULL  -- User hasn't completed this campaign yet
        ORDER BY c.created_at ASC
        LIMIT 1;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION kshipra_core.get_next_unviewed_campaign(VARCHAR) TO kshipra_admin;

COMMENT ON FUNCTION kshipra_core.get_next_unviewed_campaign(VARCHAR) IS 
'Returns next unviewed campaign for user. If all campaigns viewed, rotates to next campaign after most recently viewed (circular rotation).';
