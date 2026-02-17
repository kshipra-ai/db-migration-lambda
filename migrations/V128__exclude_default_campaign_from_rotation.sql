-- V128: Exclude default Kshipra campaign from normal QR rotation
-- The default campaign (Kshipra Universal / kshipraai.com) should only appear
-- as a last resort when NO brand campaigns are available at all.
-- Normal rotation should cycle through brand campaigns (including already-viewed ones).

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
    v_default_partner_id UUID := '00000000-0000-0000-0000-000000000002'; -- Kshipra Universal
BEGIN
    -- Check if user has any unviewed SCANNABLE brand campaigns (excluding default)
    SELECT EXISTS (
        SELECT 1
        FROM kshipra_core.campaigns c
        LEFT JOIN kshipra_core.user_deep_link_views udlv 
            ON c.campaign_id = udlv.campaign_id 
            AND udlv.user_id = p_user_id 
            AND udlv.is_completed = true
        LEFT JOIN kshipra_core.qr_campaigns qc ON qc.campaign_id = c.campaign_id
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
            AND c.scannable = true
            AND c.partner_id != v_default_partner_id  -- Exclude default campaign
            AND c.landing_url IS NOT NULL
            AND (c.start_date IS NULL OR c.start_date <= CURRENT_TIMESTAMP)
            AND (c.end_date IS NULL OR c.end_date >= CURRENT_TIMESTAMP)
            AND udlv.view_id IS NULL
            AND (qc.max_daily_scans IS NULL OR qc.max_daily_scans = 0 OR daily_scans.daily_scan_count < qc.max_daily_scans)
    ) INTO v_has_unviewed;
    
    -- If all brand campaigns viewed, rotate through them (including already-viewed)
    IF NOT v_has_unviewed THEN
        -- Get the most recently viewed campaign
        SELECT udlv.campaign_id INTO v_last_viewed_campaign_id
        FROM kshipra_core.user_deep_link_views udlv
        WHERE udlv.user_id = p_user_id
        ORDER BY udlv.session_start_at DESC
        LIMIT 1;
        
        -- Return the next brand campaign after the last viewed one (circular rotation)
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
            LEFT JOIN kshipra_core.qr_campaigns qc ON qc.campaign_id = c.campaign_id
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
                AND c.scannable = true
                AND c.partner_id != v_default_partner_id  -- Exclude default campaign
                AND c.landing_url IS NOT NULL
                AND (c.start_date IS NULL OR c.start_date <= CURRENT_TIMESTAMP)
                AND (c.end_date IS NULL OR c.end_date >= CURRENT_TIMESTAMP)
                AND (qc.max_daily_scans IS NULL OR qc.max_daily_scans = 0 OR daily_scans.daily_scan_count < qc.max_daily_scans)
        ),
        target_campaign AS (
            SELECT 
                camp_id,
                row_num,
                (SELECT row_num FROM all_campaigns WHERE camp_id = v_last_viewed_campaign_id) as last_viewed_row
            FROM all_campaigns
        )
        SELECT 
            ac.camp_id::UUID,
            ac.landing_url,
            ac.campaign_name,
            ac.campaign_description,
            ac.min_view_duration_seconds,
            ac.reward_rate,
            ac.partner_brand
        FROM all_campaigns ac
        JOIN target_campaign tc ON TRUE
        WHERE ac.row_num > COALESCE(tc.last_viewed_row, 0)
        ORDER BY ac.row_num ASC
        LIMIT 1;
        
        -- If no campaigns after last viewed, wrap around to first brand campaign
        IF NOT FOUND THEN
            RETURN QUERY
            SELECT 
                c.campaign_id::UUID,
                c.landing_url,
                c.campaign_name,
                c.campaign_description,
                COALESCE(c.min_view_duration_seconds, 10) as min_view_duration_seconds,
                c.reward_rate,
                p.brand_name as partner_brand
            FROM kshipra_core.campaigns c
            INNER JOIN kshipra_core.partners p ON c.partner_id = p.partner_id
            LEFT JOIN kshipra_core.qr_campaigns qc ON qc.campaign_id = c.campaign_id
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
                AND c.scannable = true
                AND c.partner_id != v_default_partner_id  -- Exclude default campaign
                AND c.landing_url IS NOT NULL
                AND (c.start_date IS NULL OR c.start_date <= CURRENT_TIMESTAMP)
                AND (c.end_date IS NULL OR c.end_date >= CURRENT_TIMESTAMP)
                AND (qc.max_daily_scans IS NULL OR qc.max_daily_scans = 0 OR daily_scans.daily_scan_count < qc.max_daily_scans)
            ORDER BY c.created_at ASC
            LIMIT 1;
        END IF;
        
        -- If STILL no brand campaigns found at all, fall back to default campaign
        IF NOT FOUND THEN
            RETURN QUERY
            SELECT 
                c.campaign_id::UUID,
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
                AND c.deleted = false
                AND c.partner_id = v_default_partner_id
            ORDER BY c.created_at ASC
            LIMIT 1;
        END IF;
        
        RETURN;
    END IF;
    
    -- Return next unviewed brand campaign (excludes default)
    RETURN QUERY
    SELECT 
        c.campaign_id::UUID,
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
    LEFT JOIN kshipra_core.qr_campaigns qc ON qc.campaign_id = c.campaign_id
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
        AND c.scannable = true
        AND c.partner_id != v_default_partner_id  -- Exclude default campaign
        AND c.landing_url IS NOT NULL
        AND (c.start_date IS NULL OR c.start_date <= CURRENT_TIMESTAMP)
        AND (c.end_date IS NULL OR c.end_date >= CURRENT_TIMESTAMP)
        AND udlv.view_id IS NULL
        AND (qc.max_daily_scans IS NULL OR qc.max_daily_scans = 0 OR daily_scans.daily_scan_count < qc.max_daily_scans)
    ORDER BY c.created_at ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Add comment
COMMENT ON FUNCTION kshipra_core.get_next_unviewed_campaign(VARCHAR) IS 
'V128: Excludes default Kshipra campaign from normal rotation. Brand campaigns rotate normally (unviewed first, then circular through viewed). Default campaign (kshipraai.com) only returned when zero brand campaigns exist.';
