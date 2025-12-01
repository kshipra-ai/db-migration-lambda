-- V96: Add QR scan analytics and user cohort metrics for enhanced brand insights
-- Provides dedicated QR performance tracking and user retention metrics

-- ============================================================
-- 1. QR SCAN ANALYTICS VIEW
-- Dedicated metrics for QR code performance tracking
-- ============================================================
CREATE OR REPLACE VIEW kshipra_core.brand_qr_analytics AS
SELECT 
    c.campaign_id,
    c.partner_id,
    c.campaign_name,
    COALESCE(qs.qr_code_id, 'CAMPAIGN_' || c.campaign_id) as qr_code_id,
    
    -- QR Scan Metrics
    COUNT(DISTINCT qs.scan_id) as total_qr_scans,
    COUNT(DISTINCT qs.user_id) as unique_users_via_qr,
    
    -- QR to Completion Conversion
    COUNT(DISTINCT CASE 
        WHEN v.is_completed = true AND v.user_id = qs.user_id 
        THEN qs.scan_id 
    END) as qr_scans_completed,
    
    CASE 
        WHEN COUNT(DISTINCT qs.scan_id) > 0 THEN 
            ROUND((COUNT(DISTINCT CASE 
                WHEN v.is_completed = true AND v.user_id = qs.user_id 
                THEN qs.scan_id 
            END)::numeric / COUNT(DISTINCT qs.scan_id)::numeric) * 100, 2)
        ELSE 0 
    END as qr_completion_rate_percent,
    
    -- Time-based QR metrics
    COUNT(CASE WHEN qs.scanned_at >= NOW() - INTERVAL '24 hours' THEN 1 END) as qr_scans_last_24h,
    COUNT(CASE WHEN qs.scanned_at >= NOW() - INTERVAL '7 days' THEN 1 END) as qr_scans_last_7d,
    COUNT(CASE WHEN qs.scanned_at >= NOW() - INTERVAL '30 days' THEN 1 END) as qr_scans_last_30d,
    
    -- Average points awarded from QR scans
    COALESCE(AVG(qs.points_awarded), 0) as avg_points_per_qr_scan,
    COALESCE(SUM(qs.points_awarded), 0) as total_points_from_qr,
    
    -- Peak scanning times (for optimization)
    MAX(qs.scanned_at) as last_qr_scan_at
    
FROM kshipra_core.campaigns c
LEFT JOIN kshipra_core.qr_scans qs ON c.campaign_id = qs.campaign_id
LEFT JOIN kshipra_core.user_deep_link_views v ON qs.user_id = v.user_id 
    AND v.campaign_id = c.campaign_id
    AND v.created_at >= qs.scanned_at - INTERVAL '5 minutes'
    AND v.created_at <= qs.scanned_at + INTERVAL '30 minutes'
GROUP BY c.campaign_id, c.partner_id, c.campaign_name, qs.qr_code_id;

CREATE INDEX idx_qr_scans_campaign ON kshipra_core.qr_scans(campaign_id);
CREATE INDEX idx_qr_scans_user ON kshipra_core.qr_scans(user_id);
CREATE INDEX idx_qr_scans_time ON kshipra_core.qr_scans(scanned_at DESC);

COMMENT ON VIEW kshipra_core.brand_qr_analytics IS 'QR code specific performance metrics - scan rates, completion conversion, time patterns';

-- ============================================================
-- 2. USER ENGAGEMENT COHORT ANALYTICS VIEW
-- Tracks user retention and repeat engagement patterns
-- ============================================================
CREATE OR REPLACE VIEW kshipra_core.brand_user_cohort_analytics AS
SELECT 
    c.partner_id,
    
    -- New vs Returning Users
    COUNT(DISTINCT CASE 
        WHEN v.created_at >= NOW() - INTERVAL '7 days' 
            AND NOT EXISTS (
                SELECT 1 FROM kshipra_core.user_deep_link_views v2 
                WHERE v2.user_id = v.user_id 
                AND v2.created_at < NOW() - INTERVAL '7 days'
            )
        THEN v.user_id 
    END) as new_users_last_7d,
    
    COUNT(DISTINCT CASE 
        WHEN v.created_at >= NOW() - INTERVAL '7 days'
            AND EXISTS (
                SELECT 1 FROM kshipra_core.user_deep_link_views v2 
                WHERE v2.user_id = v.user_id 
                AND v2.created_at < NOW() - INTERVAL '7 days'
            )
        THEN v.user_id 
    END) as returning_users_last_7d,
    
    -- Multi-campaign viewers (engaged users)
    COUNT(DISTINCT CASE 
        WHEN user_campaign_counts.campaign_count > 1 
        THEN user_campaign_counts.user_id 
    END) as users_viewing_multiple_campaigns,
    
    -- Average campaigns per user
    COALESCE(AVG(user_campaign_counts.campaign_count), 0) as avg_campaigns_per_user,
    
    -- Repeat redeemers (high value users)
    COUNT(DISTINCT CASE 
        WHEN user_redemption_counts.redemption_count > 1 
        THEN user_redemption_counts.user_id 
    END) as users_with_multiple_redemptions,
    
    -- Engagement frequency
    COUNT(DISTINCT CASE 
        WHEN user_view_counts.view_count >= 5 
        THEN user_view_counts.user_id 
    END) as highly_engaged_users
    
FROM kshipra_core.campaigns c
LEFT JOIN kshipra_core.user_deep_link_views v ON c.campaign_id = v.campaign_id
LEFT JOIN LATERAL (
    SELECT v3.user_id, COUNT(DISTINCT v3.campaign_id) as campaign_count
    FROM kshipra_core.user_deep_link_views v3
    WHERE v3.user_id = v.user_id
    GROUP BY v3.user_id
) user_campaign_counts ON true
LEFT JOIN LATERAL (
    SELECT r.user_id, COUNT(*) as redemption_count
    FROM kshipra_core.redemptions r
    WHERE r.user_id = v.user_id AND r.partner_id = c.partner_id
    GROUP BY r.user_id
) user_redemption_counts ON true
LEFT JOIN LATERAL (
    SELECT v4.user_id, COUNT(*) as view_count
    FROM kshipra_core.user_deep_link_views v4
    WHERE v4.user_id = v.user_id
    GROUP BY v4.user_id
) user_view_counts ON true
GROUP BY c.partner_id;

COMMENT ON VIEW kshipra_core.brand_user_cohort_analytics IS 'User retention and engagement depth metrics - new vs returning, multi-campaign viewers, repeat redeemers';

-- ============================================================
-- 3. TIME PATTERN ANALYTICS VIEW
-- Hour-of-day and day-of-week engagement patterns
-- ============================================================
CREATE OR REPLACE VIEW kshipra_core.brand_time_pattern_analytics AS
SELECT 
    c.campaign_id,
    c.partner_id,
    c.campaign_name,
    
    -- Hour of day distribution
    EXTRACT(HOUR FROM v.created_at) as hour_of_day,
    EXTRACT(DOW FROM v.created_at) as day_of_week, -- 0=Sunday, 6=Saturday
    
    -- Engagement counts
    COUNT(DISTINCT v.view_id) as views_count,
    COUNT(DISTINCT CASE WHEN v.is_completed = true THEN v.view_id END) as completions_count,
    COUNT(DISTINCT v.user_id) as unique_users_count
    
FROM kshipra_core.campaigns c
LEFT JOIN kshipra_core.user_deep_link_views v ON c.campaign_id = v.campaign_id
WHERE v.created_at >= NOW() - INTERVAL '30 days' -- Last 30 days for pattern detection
GROUP BY c.campaign_id, c.partner_id, c.campaign_name, 
         EXTRACT(HOUR FROM v.created_at), EXTRACT(DOW FROM v.created_at);

COMMENT ON VIEW kshipra_core.brand_time_pattern_analytics IS 'Hour-of-day and day-of-week engagement patterns for campaign timing optimization';

-- Grant permissions
GRANT SELECT ON kshipra_core.brand_qr_analytics TO kshipra_admin;
GRANT SELECT ON kshipra_core.brand_user_cohort_analytics TO kshipra_admin;
GRANT SELECT ON kshipra_core.brand_time_pattern_analytics TO kshipra_admin;
