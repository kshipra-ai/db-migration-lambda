-- V49__create_brand_analytics_views.sql
-- Creates views and materialized views for brand analytics dashboard
-- Provides real-time engagement metrics without exposing user PII

-- ============================================================
-- 1. CAMPAIGN ENGAGEMENT SUMMARY VIEW
-- Real-time metrics per campaign for brand dashboard
-- ============================================================
CREATE OR REPLACE VIEW kshipra_core.brand_campaign_analytics AS
SELECT 
    c.campaign_id,
    c.partner_id,
    c.campaign_name,
    c.campaign_description,
    c.reward_rate,
    c.is_active,
    c.review_status,
    c.start_date,
    c.end_date,
    c.created_at,
    
    -- Engagement Metrics
    COUNT(DISTINCT v.view_id) as total_views,
    COUNT(DISTINCT CASE WHEN v.is_completed = true THEN v.view_id END) as completed_views,
    COUNT(DISTINCT v.user_id) as unique_users,
    
    -- View Duration Stats
    AVG(CASE WHEN v.actual_view_duration_seconds IS NOT NULL 
        THEN v.actual_view_duration_seconds END) as avg_view_duration_seconds,
    MAX(v.actual_view_duration_seconds) as max_view_duration_seconds,
    MIN(CASE WHEN v.actual_view_duration_seconds > 0 
        THEN v.actual_view_duration_seconds END) as min_view_duration_seconds,
    
    -- Completion Rate
    CASE 
        WHEN COUNT(v.view_id) > 0 THEN 
            ROUND((COUNT(CASE WHEN v.is_completed = true THEN 1 END)::numeric / COUNT(v.view_id)::numeric) * 100, 2)
        ELSE 0 
    END as completion_rate_percent,
    
    -- Redemption Metrics
    COUNT(DISTINCT r.redemption_id) as total_redemptions,
    COUNT(DISTINCT CASE WHEN r.status = 'scanned' THEN r.redemption_id END) as successful_redemptions,
    COALESCE(SUM(CASE WHEN r.status = 'scanned' THEN r.points_redeemed ELSE 0 END), 0) as total_points_redeemed,
    
    -- QR Scan Stats
    COUNT(DISTINCT CASE WHEN v.qr_code_id IS NOT NULL THEN v.view_id END) as qr_scans,
    
    -- Time-based metrics
    MAX(v.session_start_at) as last_engagement_at,
    COUNT(CASE WHEN v.created_at >= NOW() - INTERVAL '24 hours' THEN 1 END) as views_last_24h,
    COUNT(CASE WHEN v.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as views_last_7d
    
FROM kshipra_core.campaigns c
LEFT JOIN kshipra_core.user_deep_link_views v ON c.campaign_id = v.campaign_id
LEFT JOIN kshipra_core.redemptions r ON c.partner_id = r.partner_id 
    AND r.created_at >= c.start_date 
    AND (c.end_date IS NULL OR r.created_at <= c.end_date)
GROUP BY 
    c.campaign_id, c.partner_id, c.campaign_name, c.campaign_description,
    c.reward_rate, c.is_active, c.review_status, c.start_date, c.end_date, c.created_at;

CREATE INDEX idx_campaign_analytics_partner ON kshipra_core.campaigns(partner_id);

COMMENT ON VIEW kshipra_core.brand_campaign_analytics IS 'Real-time campaign engagement metrics for brand dashboard - no user PII exposed';

-- ============================================================
-- 2. LOCATION-BASED ANALYTICS VIEW
-- Geographic distribution of engagement without user identification
-- ============================================================
CREATE OR REPLACE VIEW kshipra_core.brand_location_analytics AS
SELECT 
    c.campaign_id,
    c.partner_id,
    c.campaign_name,
    
    -- Location aggregation (city/region level only, no precise location)
    COALESCE(v.scan_location, 'Unknown') as location,
    
    -- Engagement counts
    COUNT(DISTINCT v.view_id) as views_count,
    COUNT(DISTINCT CASE WHEN v.is_completed = true THEN v.view_id END) as completed_views_count,
    COUNT(DISTINCT v.user_id) as unique_users_count,
    
    -- Average metrics
    AVG(CASE WHEN v.actual_view_duration_seconds IS NOT NULL 
        THEN v.actual_view_duration_seconds END) as avg_view_duration,
    
    -- Time distribution
    COUNT(CASE WHEN v.created_at >= NOW() - INTERVAL '24 hours' THEN 1 END) as views_last_24h,
    COUNT(CASE WHEN v.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as views_last_7d,
    
    MAX(v.session_start_at) as last_engagement_at
    
FROM kshipra_core.campaigns c
LEFT JOIN kshipra_core.user_deep_link_views v ON c.campaign_id = v.campaign_id
WHERE v.scan_location IS NOT NULL
GROUP BY 
    c.campaign_id, c.partner_id, c.campaign_name, v.scan_location
HAVING COUNT(v.view_id) > 0;

COMMENT ON VIEW kshipra_core.brand_location_analytics IS 'Geographic engagement distribution by city/region - aggregated data only';

-- ============================================================
-- 3. REDEMPTION ANALYTICS VIEW
-- Redemption patterns and trends for brands
-- ============================================================
CREATE OR REPLACE VIEW kshipra_core.brand_redemption_analytics AS
SELECT 
    p.partner_id,
    p.brand_name,
    p.company_name,
    
    -- Redemption Totals
    COUNT(r.redemption_id) as total_redemptions_created,
    COUNT(CASE WHEN r.status = 'scanned' THEN 1 END) as successful_redemptions,
    COUNT(CASE WHEN r.status = 'pending' THEN 1 END) as pending_redemptions,
    COUNT(CASE WHEN r.status = 'expired' THEN 1 END) as expired_redemptions,
    
    -- Points Analytics
    COALESCE(SUM(CASE WHEN r.status = 'scanned' THEN r.points_redeemed ELSE 0 END), 0) as total_points_redeemed,
    COALESCE(AVG(CASE WHEN r.status = 'scanned' THEN r.points_redeemed END), 0) as avg_points_per_redemption,
    COALESCE(MAX(CASE WHEN r.status = 'scanned' THEN r.points_redeemed END), 0) as max_points_redeemed,
    
    -- Success Rate
    CASE 
        WHEN COUNT(r.redemption_id) > 0 THEN 
            ROUND((COUNT(CASE WHEN r.status = 'scanned' THEN 1 END)::numeric / COUNT(r.redemption_id)::numeric) * 100, 2)
        ELSE 0 
    END as redemption_success_rate_percent,
    
    -- Time-based metrics
    COUNT(CASE WHEN r.created_at >= NOW() - INTERVAL '24 hours' THEN 1 END) as redemptions_last_24h,
    COUNT(CASE WHEN r.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as redemptions_last_7d,
    COUNT(CASE WHEN r.created_at >= NOW() - INTERVAL '30 days' THEN 1 END) as redemptions_last_30d,
    
    MAX(r.scanned_at) as last_redemption_at,
    
    -- User engagement (aggregated, no PII)
    COUNT(DISTINCT r.user_id) as unique_users_redeemed

FROM kshipra_core.partners p
LEFT JOIN kshipra_core.redemptions r ON p.partner_id = r.partner_id
GROUP BY p.partner_id, p.brand_name, p.company_name;

COMMENT ON VIEW kshipra_core.brand_redemption_analytics IS 'Redemption metrics and patterns for brand analytics dashboard';

-- ============================================================
-- 4. TIME-SERIES DAILY ANALYTICS MATERIALIZED VIEW
-- Daily aggregated metrics for trending and historical analysis
-- Refreshed periodically for performance
-- ============================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS kshipra_core.brand_daily_analytics AS
SELECT 
    c.campaign_id,
    c.partner_id,
    DATE(v.created_at) as analytics_date,
    
    -- Daily engagement
    COUNT(DISTINCT v.view_id) as daily_views,
    COUNT(DISTINCT CASE WHEN v.is_completed = true THEN v.view_id END) as daily_completed_views,
    COUNT(DISTINCT v.user_id) as daily_unique_users,
    
    -- Daily averages
    AVG(CASE WHEN v.actual_view_duration_seconds IS NOT NULL 
        THEN v.actual_view_duration_seconds END) as daily_avg_view_duration,
    
    -- QR scans
    COUNT(CASE WHEN v.qr_code_id IS NOT NULL THEN 1 END) as daily_qr_scans
    
FROM kshipra_core.campaigns c
LEFT JOIN kshipra_core.user_deep_link_views v ON c.campaign_id = v.campaign_id
WHERE v.created_at >= NOW() - INTERVAL '90 days' -- Last 90 days
GROUP BY c.campaign_id, c.partner_id, DATE(v.created_at);

-- Index for fast date-range queries
CREATE INDEX idx_daily_analytics_date ON kshipra_core.brand_daily_analytics(analytics_date DESC);
CREATE INDEX idx_daily_analytics_campaign ON kshipra_core.brand_daily_analytics(campaign_id, analytics_date DESC);
CREATE INDEX idx_daily_analytics_partner ON kshipra_core.brand_daily_analytics(partner_id, analytics_date DESC);

COMMENT ON MATERIALIZED VIEW kshipra_core.brand_daily_analytics IS 'Daily aggregated engagement metrics for historical trending - refreshed periodically';

-- Function to refresh materialized view (call this via cron or manually)
CREATE OR REPLACE FUNCTION kshipra_core.refresh_brand_daily_analytics()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY kshipra_core.brand_daily_analytics;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION kshipra_core.refresh_brand_daily_analytics IS 'Refreshes daily analytics materialized view - call periodically via cron';

-- ============================================================
-- 5. CAMPAIGN FUNNEL ANALYTICS VIEW
-- Conversion funnel from view -> completion -> redemption
-- ============================================================
CREATE OR REPLACE VIEW kshipra_core.brand_funnel_analytics AS
SELECT 
    c.campaign_id,
    c.partner_id,
    c.campaign_name,
    
    -- Funnel stages
    COUNT(DISTINCT v.view_id) as stage_1_views,
    COUNT(DISTINCT CASE WHEN v.is_completed = true THEN v.view_id END) as stage_2_completions,
    COUNT(DISTINCT r.redemption_id) as stage_3_redemption_attempts,
    COUNT(DISTINCT CASE WHEN r.status = 'scanned' THEN r.redemption_id END) as stage_4_successful_redemptions,
    
    -- Conversion rates
    CASE 
        WHEN COUNT(v.view_id) > 0 THEN 
            ROUND((COUNT(CASE WHEN v.is_completed = true THEN 1 END)::numeric / COUNT(v.view_id)::numeric) * 100, 2)
        ELSE 0 
    END as view_to_completion_rate,
    
    CASE 
        WHEN COUNT(CASE WHEN v.is_completed = true THEN 1 END) > 0 THEN 
            ROUND((COUNT(r.redemption_id)::numeric / COUNT(CASE WHEN v.is_completed = true THEN 1 END)::numeric) * 100, 2)
        ELSE 0 
    END as completion_to_redemption_rate,
    
    CASE 
        WHEN COUNT(r.redemption_id) > 0 THEN 
            ROUND((COUNT(CASE WHEN r.status = 'scanned' THEN 1 END)::numeric / COUNT(r.redemption_id)::numeric) * 100, 2)
        ELSE 0 
    END as redemption_success_rate
    
FROM kshipra_core.campaigns c
LEFT JOIN kshipra_core.user_deep_link_views v ON c.campaign_id = v.campaign_id
LEFT JOIN kshipra_core.redemptions r ON c.partner_id = r.partner_id 
    AND r.created_at >= c.start_date 
    AND (c.end_date IS NULL OR r.created_at <= c.end_date)
GROUP BY c.campaign_id, c.partner_id, c.campaign_name;

COMMENT ON VIEW kshipra_core.brand_funnel_analytics IS 'Conversion funnel metrics from view to successful redemption';

-- Grant permissions to admin user
GRANT SELECT ON kshipra_core.brand_campaign_analytics TO kshipra_admin;
GRANT SELECT ON kshipra_core.brand_location_analytics TO kshipra_admin;
GRANT SELECT ON kshipra_core.brand_redemption_analytics TO kshipra_admin;
GRANT SELECT ON kshipra_core.brand_daily_analytics TO kshipra_admin;
GRANT SELECT ON kshipra_core.brand_funnel_analytics TO kshipra_admin;
GRANT EXECUTE ON FUNCTION kshipra_core.refresh_brand_daily_analytics TO kshipra_admin;
