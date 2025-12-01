-- V19__create_campaign_deep_links_and_view_tracking.sql
-- Dynamic deep link rotation system with view completion tracking
-- Each campaign has ONE deep link
-- Users see different unviewed links sequentially from the GLOBAL pool of ALL campaign links

-- ==========================================
-- Add deep link fields to campaigns table
-- Each campaign has one primary deep link for rotation
-- ==========================================
ALTER TABLE kshipra_core.campaigns 
ADD COLUMN IF NOT EXISTS deep_link VARCHAR(2048),
ADD COLUMN IF NOT EXISTS deep_link_title VARCHAR(255),
ADD COLUMN IF NOT EXISTS deep_link_description TEXT,
ADD COLUMN IF NOT EXISTS min_view_duration_seconds INTEGER DEFAULT 10, -- Time required to mark link as "viewed"
ADD COLUMN IF NOT EXISTS deep_link_order INTEGER; -- Global order in rotation pool

-- Add constraint to ensure valid deep link URL format
ALTER TABLE kshipra_core.campaigns 
ADD CONSTRAINT check_valid_deep_link CHECK (deep_link IS NULL OR deep_link ~ '^https?://.*');

-- Create unique index on deep_link_order for rotation sequence
CREATE UNIQUE INDEX idx_campaigns_deep_link_order ON kshipra_core.campaigns(deep_link_order) 
WHERE deep_link_order IS NOT NULL AND is_active = true;

-- Index for active deep links
CREATE INDEX idx_campaigns_active_deep_links ON kshipra_core.campaigns(is_active, deep_link_order) 
WHERE deep_link IS NOT NULL;

-- ==========================================
-- Table: user_deep_link_views
-- Tracks which campaign deep links each user has completed viewing
-- A view is only marked "completed" when user stays for required duration
-- ==========================================
CREATE TABLE IF NOT EXISTS kshipra_core.user_deep_link_views (
    view_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(255) NOT NULL, -- References user_profile.user_id
    campaign_id UUID NOT NULL REFERENCES kshipra_core.campaigns(campaign_id) ON DELETE CASCADE,
    
    -- View Session Details
    session_start_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    session_end_at TIMESTAMP WITH TIME ZONE, -- When user closed/left the link
    actual_view_duration_seconds INTEGER, -- Calculated duration
    required_duration_seconds INTEGER NOT NULL, -- Campaign's requirement at time of view
    
    -- View Completion Status
    is_completed BOOLEAN DEFAULT false, -- true only if actual_view_duration >= required_duration
    completed_at TIMESTAMP WITH TIME ZONE, -- When view was marked complete
    
    -- Scan context
    qr_code_id VARCHAR(255), -- If scanned via QR
    user_agent TEXT,
    ip_address VARCHAR(45),
    scan_location TEXT,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Ensure one view record per user per campaign (can be updated)
    CONSTRAINT unique_user_campaign_view UNIQUE (user_id, campaign_id)
);

-- Indexes for fast lookups
CREATE INDEX idx_user_deep_link_views_user_id ON kshipra_core.user_deep_link_views(user_id);
CREATE INDEX idx_user_deep_link_views_campaign_id ON kshipra_core.user_deep_link_views(campaign_id);
CREATE INDEX idx_user_deep_link_views_completed ON kshipra_core.user_deep_link_views(user_id, is_completed);
CREATE INDEX idx_user_deep_link_views_session_start ON kshipra_core.user_deep_link_views(session_start_at);

-- ==========================================
-- Function: Auto-update user_deep_link_views.updated_at
-- ==========================================
CREATE OR REPLACE FUNCTION kshipra_core.update_deep_link_views_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto-updating updated_at
CREATE TRIGGER trigger_deep_link_views_updated_at
    BEFORE UPDATE ON kshipra_core.user_deep_link_views
    FOR EACH ROW
    EXECUTE FUNCTION kshipra_core.update_deep_link_views_updated_at();

-- ==========================================
-- Function: Auto-increment campaign engagement stats when view completes
-- ==========================================
CREATE OR REPLACE FUNCTION kshipra_core.increment_campaign_stats_on_complete()
RETURNS TRIGGER AS $$
BEGIN
    -- Only increment when view becomes completed
    IF NEW.is_completed = true AND (OLD.is_completed IS NULL OR OLD.is_completed = false) THEN
        UPDATE kshipra_core.campaigns 
        SET total_engagements = total_engagements + 1
        WHERE campaign_id = NEW.campaign_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto-incrementing campaign stats
CREATE TRIGGER trigger_increment_campaign_stats
    AFTER INSERT OR UPDATE ON kshipra_core.user_deep_link_views
    FOR EACH ROW
    EXECUTE FUNCTION kshipra_core.increment_campaign_stats_on_complete();

-- ==========================================
-- Function: Get next unviewed deep link for user
-- Returns the next campaign deep link in global rotation that user hasn't completed viewing
-- Once all links are viewed, cycles back to the beginning
-- ==========================================
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
            AND udlv.user_id = p_user_id 
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
            AND udlv.user_id = p_user_id 
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

-- ==========================================
-- Function: Start deep link view session
-- Records when user starts viewing a campaign deep link
-- ==========================================
CREATE OR REPLACE FUNCTION kshipra_core.start_deep_link_view_session(
    p_user_id VARCHAR(255),
    p_campaign_id UUID,
    p_required_duration_seconds INTEGER,
    p_qr_code_id VARCHAR(255) DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_ip_address VARCHAR(45) DEFAULT NULL,
    p_scan_location TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_view_id UUID;
BEGIN
    -- Insert or update view record
    INSERT INTO kshipra_core.user_deep_link_views (
        user_id,
        campaign_id,
        session_start_at,
        required_duration_seconds,
        qr_code_id,
        user_agent,
        ip_address,
        scan_location,
        is_completed
    ) VALUES (
        p_user_id,
        p_campaign_id,
        CURRENT_TIMESTAMP,
        p_required_duration_seconds,
        p_qr_code_id,
        p_user_agent,
        p_ip_address,
        p_scan_location,
        false
    )
    ON CONFLICT (user_id, campaign_id) DO UPDATE SET
        session_start_at = CURRENT_TIMESTAMP,
        required_duration_seconds = p_required_duration_seconds,
        is_completed = false,
        session_end_at = NULL,
        actual_view_duration_seconds = NULL,
        completed_at = NULL
    RETURNING view_id INTO v_view_id;
    
    RETURN v_view_id;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- Function: Complete deep link view session
-- Marks view as completed if duration requirement met
-- ==========================================
CREATE OR REPLACE FUNCTION kshipra_core.complete_deep_link_view_session(
    p_user_id VARCHAR(255),
    p_campaign_id UUID,
    p_actual_duration_seconds INTEGER
)
RETURNS BOOLEAN AS $$
DECLARE
    v_required_duration INTEGER;
    v_is_completed BOOLEAN;
BEGIN
    -- Get required duration for this view
    SELECT required_duration_seconds INTO v_required_duration
    FROM kshipra_core.user_deep_link_views
    WHERE user_id = p_user_id AND campaign_id = p_campaign_id;
    
    IF v_required_duration IS NULL THEN
        RETURN false; -- View session not found
    END IF;
    
    -- Check if duration requirement met
    v_is_completed := (p_actual_duration_seconds >= v_required_duration);
    
    -- Update view record
    UPDATE kshipra_core.user_deep_link_views
    SET 
        session_end_at = CURRENT_TIMESTAMP,
        actual_view_duration_seconds = p_actual_duration_seconds,
        is_completed = v_is_completed,
        completed_at = CASE WHEN v_is_completed THEN CURRENT_TIMESTAMP ELSE NULL END
    WHERE user_id = p_user_id AND campaign_id = p_campaign_id;
    
    RETURN v_is_completed;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- Grant permissions
-- ==========================================
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.user_deep_link_views TO kshipra_admin;
GRANT EXECUTE ON FUNCTION kshipra_core.get_next_unviewed_deep_link TO kshipra_admin;
GRANT EXECUTE ON FUNCTION kshipra_core.start_deep_link_view_session TO kshipra_admin;
GRANT EXECUTE ON FUNCTION kshipra_core.complete_deep_link_view_session TO kshipra_admin;

-- Grant lambda user (read/write for tracking)
GRANT SELECT, INSERT, UPDATE ON kshipra_core.user_deep_link_views TO lambda_tree_planting;
GRANT EXECUTE ON FUNCTION kshipra_core.get_next_unviewed_deep_link TO lambda_tree_planting;
GRANT EXECUTE ON FUNCTION kshipra_core.start_deep_link_view_session TO lambda_tree_planting;
GRANT EXECUTE ON FUNCTION kshipra_core.complete_deep_link_view_session TO lambda_tree_planting;

-- ==========================================
-- Sample Data: Set deep links for existing campaigns
-- Populate deep_link field from landing_url for existing campaigns
-- Assign sequential order for rotation
-- ==========================================
DO $$
DECLARE
    camp RECORD;
    current_order INTEGER := 1;
BEGIN
    FOR camp IN SELECT campaign_id, campaign_name, landing_url FROM kshipra_core.campaigns WHERE is_active = true AND landing_url IS NOT NULL ORDER BY created_at ASC LOOP
        UPDATE kshipra_core.campaigns
        SET 
            deep_link = camp.landing_url,
            deep_link_title = camp.campaign_name || ' - Featured Content',
            deep_link_description = 'Discover exclusive content and special offers from ' || camp.campaign_name,
            min_view_duration_seconds = 10, -- Default 10 seconds
            deep_link_order = current_order
        WHERE campaign_id = camp.campaign_id;
        
        current_order := current_order + 1;
        
        RAISE NOTICE 'Set deep link for campaign: % (order: %)', camp.campaign_name, current_order - 1;
    END LOOP;
    
    RAISE NOTICE 'Initialized % campaigns with deep links', current_order - 1;
END $$;

-- ==========================================
-- Views for analytics
-- ==========================================

-- View: Deep link performance analytics
CREATE OR REPLACE VIEW kshipra_core.v_deep_link_analytics AS
SELECT 
    c.campaign_id,
    c.campaign_name,
    c.partner_id,
    p.brand_name,
    c.deep_link,
    c.deep_link_title,
    c.deep_link_order,
    c.min_view_duration_seconds,
    c.is_active,
    -- View statistics
    COUNT(DISTINCT udlv.user_id) as total_unique_viewers,
    COUNT(DISTINCT CASE WHEN udlv.is_completed THEN udlv.user_id END) as completed_viewers,
    COUNT(DISTINCT CASE WHEN NOT udlv.is_completed THEN udlv.user_id END) as incomplete_viewers,
    -- Duration statistics
    AVG(udlv.actual_view_duration_seconds) as avg_view_duration_seconds,
    MIN(udlv.actual_view_duration_seconds) as min_view_duration_seconds_actual,
    MAX(udlv.actual_view_duration_seconds) as max_view_duration_seconds,
    -- Completion rate
    CASE 
        WHEN COUNT(DISTINCT udlv.user_id) > 0 THEN 
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN udlv.is_completed THEN udlv.user_id END) / COUNT(DISTINCT udlv.user_id), 2)
        ELSE 0
    END as completion_rate_percent,
    c.created_at,
    c.updated_at
FROM kshipra_core.campaigns c
INNER JOIN kshipra_core.partners p ON c.partner_id = p.partner_id
LEFT JOIN kshipra_core.user_deep_link_views udlv ON c.campaign_id = udlv.campaign_id
WHERE c.deep_link IS NOT NULL
GROUP BY c.campaign_id, c.campaign_name, c.partner_id, p.brand_name, 
         c.deep_link, c.deep_link_title, c.deep_link_order, 
         c.min_view_duration_seconds, c.is_active, c.created_at, c.updated_at;

GRANT SELECT ON kshipra_core.v_deep_link_analytics TO kshipra_admin;
GRANT SELECT ON kshipra_core.v_deep_link_analytics TO lambda_tree_planting;

-- View: User deep link viewing progress
CREATE OR REPLACE VIEW kshipra_core.v_user_deep_link_progress AS
SELECT 
    user_id,
    COUNT(*) as total_links_viewed,
    COUNT(CASE WHEN is_completed THEN 1 END) as completed_links,
    COUNT(CASE WHEN NOT is_completed THEN 1 END) as incomplete_links,
    AVG(actual_view_duration_seconds) as avg_view_duration,
    MAX(session_start_at) as last_view_at,
    -- Calculate total available links
    (SELECT COUNT(*) FROM kshipra_core.campaigns WHERE deep_link IS NOT NULL AND is_active = true) as total_available_links,
    -- Progress percentage
    CASE 
        WHEN (SELECT COUNT(*) FROM kshipra_core.campaigns WHERE deep_link IS NOT NULL AND is_active = true) > 0 THEN
            ROUND(100.0 * COUNT(CASE WHEN is_completed THEN 1 END) / (SELECT COUNT(*) FROM kshipra_core.campaigns WHERE deep_link IS NOT NULL AND is_active = true), 2)
        ELSE 0
    END as progress_percent
FROM kshipra_core.user_deep_link_views
GROUP BY user_id;

GRANT SELECT ON kshipra_core.v_user_deep_link_progress TO kshipra_admin;
GRANT SELECT ON kshipra_core.v_user_deep_link_progress TO lambda_tree_planting;

-- ==========================================
-- Comments for documentation
-- ==========================================
COMMENT ON COLUMN kshipra_core.campaigns.deep_link IS 'Deep link URL shown to users when they scan QR codes - part of global rotation pool';
COMMENT ON COLUMN kshipra_core.campaigns.min_view_duration_seconds IS 'Minimum time (in seconds) user must view link before it counts as completed';
COMMENT ON COLUMN kshipra_core.campaigns.deep_link_order IS 'Global sequential order for link rotation across all campaigns';
COMMENT ON TABLE kshipra_core.user_deep_link_views IS 'Tracks user viewing sessions for campaign deep links with completion status based on duration';
COMMENT ON FUNCTION kshipra_core.get_next_unviewed_deep_link IS 'Returns next unviewed campaign deep link for user in global rotation order, cycles back after viewing all';
COMMENT ON FUNCTION kshipra_core.start_deep_link_view_session IS 'Starts a new view session when user opens a deep link';
COMMENT ON FUNCTION kshipra_core.complete_deep_link_view_session IS 'Completes view session and marks as viewed if duration requirement met';
COMMENT ON VIEW kshipra_core.v_deep_link_analytics IS 'Analytics showing deep link performance, completion rates, and duration statistics';
COMMENT ON VIEW kshipra_core.v_user_deep_link_progress IS 'User-level progress tracking showing how many links viewed vs available';
