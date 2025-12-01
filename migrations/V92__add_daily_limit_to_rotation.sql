-- V92: P1 Fix - Add daily scan limit check to campaign rotation
-- Ensures campaigns with max_daily_scans are filtered out if user exceeded their daily limit

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
    -- Check if user has any unviewed campaigns that haven't hit daily limits
    SELECT EXISTS (
        SELECT 1
        FROM kshipra_core.campaigns c
        LEFT JOIN kshipra_core.user_deep_link_views udlv 
            ON c.campaign_id = udlv.campaign_id 
            AND udlv.user_id = p_user_id 
            AND udlv.is_completed = true
        -- P1 FIX: Check daily scan limit
        LEFT JOIN LATERAL (
            SELECT COUNT(*) as daily_scan_count
            FROM kshipra_core.qr_scans qs
            WHERE qs.user_id = p_user_id
              AND qs.campaign_id = c.campaign_id
              AND qs.scanned_at >= NOW() - INTERVAL '24 hours'
        ) daily_scans ON true
        WHERE 
            c.is_active = true
            AND c.deleted = false
            AND c.review_status = 'approved'
            AND c.landing_url IS NOT NULL
            AND (c.start_date IS NULL OR c.start_date <= CURRENT_TIMESTAMP)
            AND (c.end_date IS NULL OR c.end_date >= CURRENT_TIMESTAMP)
            AND udlv.view_id IS NULL  -- Not yet completed
            -- P1 FIX: Exclude campaigns where user hit daily limit
            AND (c.max_daily_scans IS NULL OR c.max_daily_scans = 0 OR daily_scans.daily_scan_count < c.max_daily_scans)
    ) INTO v_has_unviewed;
    
    -- If user has viewed all campaigns OR hit daily limits, rotate to next available one
    IF NOT v_has_unviewed THEN
        -- Get the most recently viewed campaign
        SELECT udlv.campaign_id INTO v_last_viewed_campaign_id
        FROM kshipra_core.user_deep_link_views udlv
        WHERE udlv.user_id = p_user_id
        ORDER BY udlv.session_start_at DESC
        LIMIT 1;
        
        -- Return the next campaign after the last viewed one (circular rotation)
        -- P1 FIX: Filter out campaigns that hit daily limits
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
            -- P1 FIX: Check daily scan limit
            LEFT JOIN LATERAL (
                SELECT COUNT(*) as daily_scan_count
                FROM kshipra_core.qr_scans qs
                WHERE qs.user_id = p_user_id
                  AND qs.campaign_id = c.campaign_id
                  AND qs.scanned_at >= NOW() - INTERVAL '24 hours'
            ) daily_scans ON true
            WHERE 
                c.is_active = true
                AND c.deleted = false
                AND p.is_active = true
                AND c.review_status = 'approved'
                AND c.landing_url IS NOT NULL
                AND (c.start_date IS NULL OR c.start_date <= CURRENT_TIMESTAMP)
                AND (c.end_date IS NULL OR c.end_date >= CURRENT_TIMESTAMP)
                -- P1 FIX: Exclude campaigns where user hit daily limit
                AND (c.max_daily_scans IS NULL OR c.max_daily_scans = 0 OR daily_scans.daily_scan_count < c.max_daily_scans)
        ),
        last_campaign_position AS (
            SELECT row_num
            FROM all_campaigns
            WHERE camp_id = v_last_viewed_campaign_id
        )
        SELECT 
            ac.camp_id,
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
        -- Fallback: if no last viewed found, return first available campaign
        SELECT 
            ac.camp_id,
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
        -- Return next unviewed campaign that hasn't hit daily limits
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
        -- P1 FIX: Check daily scan limit
        LEFT JOIN LATERAL (
            SELECT COUNT(*) as daily_scan_count
            FROM kshipra_core.qr_scans qs
            WHERE qs.user_id = p_user_id
              AND qs.campaign_id = c.campaign_id
              AND qs.scanned_at >= NOW() - INTERVAL '24 hours'
        ) daily_scans ON true
        WHERE 
            c.is_active = true
            AND c.deleted = false
            AND p.is_active = true
            AND c.review_status = 'approved'
            AND c.landing_url IS NOT NULL
            AND (c.start_date IS NULL OR c.start_date <= CURRENT_TIMESTAMP)
            AND (c.end_date IS NULL OR c.end_date >= CURRENT_TIMESTAMP)
            AND udlv.view_id IS NULL  -- User hasn't completed this campaign yet
            -- P1 FIX: Exclude campaigns where user hit daily limit
            AND (c.max_daily_scans IS NULL OR c.max_daily_scans = 0 OR daily_scans.daily_scan_count < c.max_daily_scans)
        ORDER BY c.created_at ASC
        LIMIT 1;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION kshipra_core.get_next_unviewed_campaign(VARCHAR) TO kshipra_admin;

COMMENT ON FUNCTION kshipra_core.get_next_unviewed_campaign(VARCHAR) IS 
'P1 FIX: Returns next unviewed APPROVED, NON-DELETED campaign for user that hasnt hit max_daily_scans limit. Only shows campaigns with review_status = approved AND deleted = false. Filters out campaigns where user has reached max_daily_scans in last 24 hours. If all campaigns viewed or limited, rotates to next available campaign (circular rotation).';
