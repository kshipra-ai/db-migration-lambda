-- Migration: Add Unity and IronSource ad tracking columns
-- Version: V107
-- Date: 2026-01-08
-- Description: Adds columns to track Unity and IronSource ad views separately from Google ads

-- Add Unity and IronSource ad count columns to user_daily_ad_views table
ALTER TABLE kshipra_core.user_daily_ad_views
ADD COLUMN IF NOT EXISTS unity_ad_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS ironsource_ad_count INTEGER DEFAULT 0;

-- Add comments for clarity
COMMENT ON COLUMN kshipra_core.user_daily_ad_views.unity_ad_count IS 'Number of Unity ads watched today';
COMMENT ON COLUMN kshipra_core.user_daily_ad_views.ironsource_ad_count IS 'Number of IronSource ads watched today';

-- Insert system configurations for Unity and IronSource daily limits
INSERT INTO kshipra_core.system_configurations (config_key, config_value, description, is_active, created_at, updated_at)
VALUES 
  ('daily_unity_ad_limit', '{"limit": 10}', 'Maximum number of Unity ads a user can watch per day', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  ('daily_ironsource_ad_limit', '{"limit": 10}', 'Maximum number of IronSource ads a user can watch per day', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (config_key) DO NOTHING;

-- Verify the changes
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_schema = 'kshipra_core'
AND table_name = 'user_daily_ad_views'
AND column_name IN ('unity_ad_count', 'ironsource_ad_count');

SELECT config_key, config_value, is_active
FROM kshipra_core.system_configurations
WHERE config_key IN ('daily_unity_ad_limit', 'daily_ironsource_ad_limit');
