-- V25: Fix get_next_unviewed_deep_link function type casting
-- Explicitly drop and recreate with proper type handling

DROP FUNCTION IF EXISTS kshipra_core.get_next_unviewed_deep_link(VARCHAR);
DROP FUNCTION IF EXISTS kshipra_core.get_next_unviewed_deep_link(TEXT);
DROP FUNCTION IF EXISTS kshipra_core.get_next_unviewed_deep_link(UUID);

CREATE OR REPLACE FUNCTION kshipra_core.get_next_unviewed_deep_link(
    p_user_id VARCHAR(255)
)
RETURNS TABLE (
    campaign_id UUID,
    deep_link VARCHAR(2048),
    deep_link_title VARCHAR(255),
    deep_link_description TEXT,
    min_view_duration_seconds INTEGER,
    campaign_name VARCHAR(255),
    reward_rate INTEGER,
    partner_brand VARCHAR(255),
    deep_link_order INTEGER
) AS $$
DECLARE
    v_has_unviewed BOOLEAN;
BEGIN
    -- Check if user has any unviewed links
    SELECT EXISTS (
        SELECT 1
        FROM kshipra_core.campaigns c
        LEFT JOIN kshipra_core.user_deep_link_views udlv 
            ON c.campaign_id = udlv.campaign_id 
            AND udlv.user_id = p_user_id::VARCHAR(255)
            AND udlv.is_completed = true
        WHERE 
            c.is_active = true
            AND c.deep_link IS NOT NULL
            AND (c.start_date IS NULL OR c.start_date <= CURRENT_TIMESTAMP)
            AND (c.end_date IS NULL OR c.end_date >= CURRENT_TIMESTAMP)
            AND udlv.view_id IS NULL  -- Not yet completed
    ) INTO v_has_unviewed;
    
    -- If user has viewed all links, reset and start from beginning
    IF NOT v_has_unviewed THEN
        RETURN QUERY
        SELECT 
            c.campaign_id,
            c.deep_link,
            c.deep_link_title,
            c.deep_link_description,
            COALESCE(c.min_view_duration_seconds, 10) as min_view_duration_seconds,
            c.campaign_name,
            c.reward_rate,
            p.brand_name as partner_brand,
            c.deep_link_order
        FROM kshipra_core.campaigns c
        INNER JOIN kshipra_core.partners p ON c.partner_id = p.partner_id
        WHERE 
            c.is_active = true
            AND p.is_active = true
            AND c.deep_link IS NOT NULL
            AND (c.start_date IS NULL OR c.start_date <= CURRENT_TIMESTAMP)
            AND (c.end_date IS NULL OR c.end_date >= CURRENT_TIMESTAMP)
        ORDER BY COALESCE(c.deep_link_order, 999999) ASC, c.created_at ASC
        LIMIT 1;
    ELSE
        -- Return next unviewed link in order
        RETURN QUERY
        SELECT 
            c.campaign_id,
            c.deep_link,
            c.deep_link_title,
            c.deep_link_description,
            COALESCE(c.min_view_duration_seconds, 10) as min_view_duration_seconds,
            c.campaign_name,
            c.reward_rate,
            p.brand_name as partner_brand,
            c.deep_link_order
        FROM kshipra_core.campaigns c
        INNER JOIN kshipra_core.partners p ON c.partner_id = p.partner_id
        LEFT JOIN kshipra_core.user_deep_link_views udlv 
            ON c.campaign_id = udlv.campaign_id 
            AND udlv.user_id = p_user_id::VARCHAR(255)
            AND udlv.is_completed = true
        WHERE 
            c.is_active = true
            AND p.is_active = true
            AND c.deep_link IS NOT NULL
            AND (c.start_date IS NULL OR c.start_date <= CURRENT_TIMESTAMP)
            AND (c.end_date IS NULL OR c.end_date >= CURRENT_TIMESTAMP)
            AND udlv.view_id IS NULL  -- User hasn't completed this link yet
        ORDER BY COALESCE(c.deep_link_order, 999999) ASC, c.created_at ASC
        LIMIT 1;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION kshipra_core.get_next_unviewed_deep_link(VARCHAR) TO kshipra_admin;

-- Set deep_link_order for campaigns if not set
UPDATE kshipra_core.campaigns
SET deep_link_order = subquery.row_num
FROM (
    SELECT campaign_id, ROW_NUMBER() OVER (ORDER BY created_at) as row_num
    FROM kshipra_core.campaigns
    WHERE deep_link IS NOT NULL AND deep_link_order IS NULL
) AS subquery
WHERE campaigns.campaign_id = subquery.campaign_id;

COMMENT ON FUNCTION kshipra_core.get_next_unviewed_deep_link(VARCHAR) IS 
'Returns next unviewed campaign deep link for user in global rotation order, cycles back after viewing all';
