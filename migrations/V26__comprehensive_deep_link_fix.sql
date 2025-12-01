-- V26: Comprehensive fix for deep link rotation system
-- Ensures all pieces work together correctly

-- First, ensure all campaigns have partner_id set properly
-- Check if any campaigns have NULL partner_id and fix them
DO $$
DECLARE
    default_partner_id UUID;
BEGIN
    -- Get the first active partner as default
    SELECT partner_id INTO default_partner_id
    FROM kshipra_core.partners
    WHERE is_active = true
    LIMIT 1;
    
    -- Update campaigns with NULL partner_id
    IF default_partner_id IS NOT NULL THEN
        UPDATE kshipra_core.campaigns
        SET partner_id = default_partner_id
        WHERE partner_id IS NULL;
    END IF;
END $$;

-- Ensure deep_link_order is set for all campaigns with deep_link
UPDATE kshipra_core.campaigns
SET deep_link_order = subquery.row_num
FROM (
    SELECT campaign_id, ROW_NUMBER() OVER (ORDER BY created_at) as row_num
    FROM kshipra_core.campaigns
    WHERE deep_link IS NOT NULL
) AS subquery
WHERE campaigns.campaign_id = subquery.campaign_id;

-- Recreate the function one more time with explicit column returns
DROP FUNCTION IF EXISTS kshipra_core.get_next_unviewed_deep_link(VARCHAR);

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
BEGIN
    -- Return first unviewed campaign, or first campaign if all viewed
    RETURN QUERY
    SELECT 
        c.campaign_id::UUID,
        c.deep_link::VARCHAR(2048),
        COALESCE(c.deep_link_title, '')::VARCHAR(255),
        COALESCE(c.deep_link_description, '')::TEXT,
        COALESCE(c.min_view_duration_seconds, 5)::INTEGER,
        COALESCE(c.campaign_name, '')::VARCHAR(255),
        COALESCE(c.reward_rate, 25)::INTEGER,
        COALESCE(p.brand_name, 'Partner')::VARCHAR(255),
        COALESCE(c.deep_link_order, 1)::INTEGER
    FROM kshipra_core.campaigns c
    INNER JOIN kshipra_core.partners p ON c.partner_id = p.partner_id
    LEFT JOIN kshipra_core.user_deep_link_views udlv 
        ON c.campaign_id = udlv.campaign_id 
        AND udlv.user_id = p_user_id
        AND udlv.is_completed = true
    WHERE 
        c.is_active = true
        AND p.is_active = true
        AND c.deep_link IS NOT NULL
        AND c.deep_link != ''
        AND udlv.view_id IS NULL  -- Not completed by this user
    ORDER BY COALESCE(c.deep_link_order, 999999) ASC
    LIMIT 1;
    
    -- If no result (all completed), return first campaign
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT 
            c.campaign_id::UUID,
            c.deep_link::VARCHAR(2048),
            COALESCE(c.deep_link_title, '')::VARCHAR(255),
            COALESCE(c.deep_link_description, '')::TEXT,
            COALESCE(c.min_view_duration_seconds, 5)::INTEGER,
            COALESCE(c.campaign_name, '')::VARCHAR(255),
            COALESCE(c.reward_rate, 25)::INTEGER,
            COALESCE(p.brand_name, 'Partner')::VARCHAR(255),
            COALESCE(c.deep_link_order, 1)::INTEGER
        FROM kshipra_core.campaigns c
        INNER JOIN kshipra_core.partners p ON c.partner_id = p.partner_id
        WHERE 
            c.is_active = true
            AND p.is_active = true
            AND c.deep_link IS NOT NULL
            AND c.deep_link != ''
        ORDER BY COALESCE(c.deep_link_order, 999999) ASC
        LIMIT 1;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION kshipra_core.get_next_unviewed_deep_link(VARCHAR) TO kshipra_admin;

COMMENT ON FUNCTION kshipra_core.get_next_unviewed_deep_link(VARCHAR) IS 
'Returns next unviewed campaign deep link for user, with explicit type casting';
