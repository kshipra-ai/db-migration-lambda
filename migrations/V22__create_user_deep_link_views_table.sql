-- V22: Create user_deep_link_views table (V19 was marked as applied but never actually ran)
-- This table tracks which campaign deep links each user has viewed and completed

-- Drop table if exists to start fresh
DROP TABLE IF EXISTS kshipra_core.user_deep_link_views CASCADE;

-- Create the table
CREATE TABLE kshipra_core.user_deep_link_views (
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

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.user_deep_link_views TO kshipra_admin;

COMMENT ON TABLE kshipra_core.user_deep_link_views IS 'Tracks user viewing sessions for campaign deep links with completion status based on duration';
