-- V135: Insert reward_methods_config into system_configurations
-- Controls which reward methods are visible to users in the mobile app

INSERT INTO kshipra_core.system_configurations (config_key, config_value, description, is_active, created_at, updated_at, updated_by)
VALUES (
  'reward_methods_config',
  '{"google_ads_enabled": true, "unity_ads_enabled": true, "ironsource_ads_enabled": true, "surveys_enabled": true, "tapjoy_enabled": true}'::jsonb,
  'Controls which reward methods are visible to users in the mobile app',
  true,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP,
  'system'
)
ON CONFLICT (config_key) DO NOTHING;
