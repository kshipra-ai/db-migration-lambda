-- Migration: Add daily ad limit configuration and tracking
-- Version: 106
-- Description: Add configuration for daily ad limits and track user ad views

-- Insert daily ad limit configuration into existing system_configurations table
INSERT INTO kshipra_core.system_configurations (config_key, config_value, description, updated_by)
VALUES (
    'daily_google_ad_limit', 
    '{"limit": 100}'::jsonb, 
    'Maximum number of Google ads a user can watch per day',
    'system'
)
ON CONFLICT (config_key) DO NOTHING;

-- Create table to track daily ad views per user
CREATE TABLE IF NOT EXISTS kshipra_core.user_daily_ad_views (
    user_id TEXT NOT NULL,
    view_date DATE NOT NULL,
    ad_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, view_date),
    CONSTRAINT fk_user_daily_ad_views_user
        FOREIGN KEY (user_id) 
        REFERENCES kshipra_core.user_profile(user_id)
        ON DELETE CASCADE
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_daily_ad_views_date 
ON kshipra_core.user_daily_ad_views(view_date);

-- Add comments
COMMENT ON TABLE kshipra_core.user_daily_ad_views IS 'Tracks daily ad views per user to enforce daily limits';
COMMENT ON COLUMN kshipra_core.user_daily_ad_views.view_date IS 'Date of ad views (UTC)';
COMMENT ON COLUMN kshipra_core.user_daily_ad_views.ad_count IS 'Number of ads watched on this date';
