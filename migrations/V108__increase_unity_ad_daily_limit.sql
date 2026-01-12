-- Migration: Increase Unity Ads daily limit to 100 for testing
-- Version: V108
-- Date: 2026-01-09
-- Description: Temporarily increase Unity Ads daily limit from 10 to 100 for testing purposes

-- Update Unity Ads daily limit
UPDATE kshipra_core.system_configurations
SET 
  config_value = '{"limit": 100}',
  updated_at = CURRENT_TIMESTAMP
WHERE config_key = 'daily_unity_ad_limit';

-- Verify the change
SELECT config_key, config_value, is_active, updated_at
FROM kshipra_core.system_configurations
WHERE config_key = 'daily_unity_ad_limit';
