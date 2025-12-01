-- V36: Remove deep_link columns and migrate to use landing_url exclusively
-- This simplifies the architecture by using a single URL field (landing_url) for campaign websites

-- Step 1: Drop the get_next_unviewed_deep_link function (will recreate using landing_url)
DROP FUNCTION IF EXISTS kshipra_core.get_next_unviewed_deep_link(VARCHAR);

-- Step 2: Create new function that uses landing_url instead of deep_link
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
    
    -- If user has viewed all campaigns, reset and start from beginning
    IF NOT v_has_unviewed THEN
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
        WHERE 
            c.is_active = true
            AND p.is_active = true
            AND c.landing_url IS NOT NULL
            AND (c.start_date IS NULL OR c.start_date <= CURRENT_TIMESTAMP)
            AND (c.end_date IS NULL OR c.end_date >= CURRENT_TIMESTAMP)
        ORDER BY c.created_at ASC
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
'Returns next unviewed campaign for user rotation using landing_url, cycles back after viewing all';

-- Step 3: Drop indexes related to deep_link
DROP INDEX IF EXISTS kshipra_core.idx_campaigns_deep_link_order;
DROP INDEX IF EXISTS kshipra_core.idx_campaigns_active_deep_links;

-- Step 4: Drop constraint related to deep_link
ALTER TABLE kshipra_core.campaigns DROP CONSTRAINT IF EXISTS check_valid_deep_link;

-- Step 5: Drop deep_link columns from campaigns table
ALTER TABLE kshipra_core.campaigns 
DROP COLUMN IF EXISTS deep_link,
DROP COLUMN IF EXISTS deep_link_title,
DROP COLUMN IF EXISTS deep_link_description,
DROP COLUMN IF EXISTS deep_link_order;

-- Note: We keep min_view_duration_seconds as it's still useful for landing_url tracking
-- Note: We keep user_deep_link_views table as it now tracks landing_url view sessions

-- Step 6: Add index for active campaigns with landing_url
CREATE INDEX IF NOT EXISTS idx_campaigns_active_landing_url 
ON kshipra_core.campaigns(is_active, created_at) 
WHERE landing_url IS NOT NULL;

-- Step 7: Update comments
COMMENT ON COLUMN kshipra_core.campaigns.landing_url IS 'Campaign website URL shown to users when they scan QR codes';
COMMENT ON COLUMN kshipra_core.campaigns.min_view_duration_seconds IS 'Minimum time (in seconds) user must view landing_url before rewards are awarded';
COMMENT ON TABLE kshipra_core.user_deep_link_views IS 'Tracks user view sessions for campaign landing URLs (historical table name kept for compatibility)';
