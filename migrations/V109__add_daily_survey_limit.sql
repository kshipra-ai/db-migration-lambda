-- Migration: Add daily CPX survey limit configuration and tracking
-- Version: 109
-- Description: Add configuration for daily survey limits and track user survey completions

-- Add survey count column to existing user_daily_ad_views table (rename would be too disruptive)
-- We'll repurpose this table for all daily reward tracking
ALTER TABLE kshipra_core.user_daily_ad_views
ADD COLUMN IF NOT EXISTS cpx_survey_count INTEGER DEFAULT 0;

-- Add comment for the new column
COMMENT ON COLUMN kshipra_core.user_daily_ad_views.cpx_survey_count IS 'Number of CPX surveys completed today';

-- Insert daily survey limit configuration
INSERT INTO kshipra_core.system_configurations (config_key, config_value, description, updated_by)
VALUES (
    'daily_cpx_survey_limit', 
    '{"limit": 10}'::jsonb, 
    'Maximum number of CPX surveys a user can complete per day (default: 10)',
    'system'
)
ON CONFLICT (config_key) DO NOTHING;

-- For clarity, let's also rename the table conceptually in comments (we keep the table name for backward compatibility)
COMMENT ON TABLE kshipra_core.user_daily_ad_views IS 'Tracks daily reward activities per user (ads and surveys) to enforce daily limits';
