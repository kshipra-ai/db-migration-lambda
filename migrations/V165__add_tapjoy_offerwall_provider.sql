-- V164: Add Unity/Tapjoy Offerwall provider and reward tracking

ALTER TABLE kshipra_core.user_daily_ad_views
  ADD COLUMN IF NOT EXISTS tapjoy_offerwall_count INTEGER DEFAULT 0;

COMMENT ON COLUMN kshipra_core.user_daily_ad_views.tapjoy_offerwall_count IS
  'Number of Tapjoy Offerwall rewards credited today';

INSERT INTO kshipra_core.survey_providers (
  name,
  display_name,
  is_active,
  credentials_ssm_path,
  base_url,
  webhook_path,
  priority,
  config,
  created_at,
  updated_at
)
VALUES (
  'tapjoy',
  'Tapjoy Offerwall',
  true,
  '/kshipra/offerwall/tapjoy/credentials',
  'https://ltv.tapjoy.com',
  '/webhooks/tapjoy',
  80,
  '{
    "offerwall": true,
    "managedBy": "Unity Grow",
    "requiresServerSideCallback": true,
    "currency": "CAD"
  }'::jsonb,
  NOW(),
  NOW()
)
ON CONFLICT (name) DO UPDATE
SET
  display_name = EXCLUDED.display_name,
  is_active = EXCLUDED.is_active,
  credentials_ssm_path = EXCLUDED.credentials_ssm_path,
  base_url = EXCLUDED.base_url,
  webhook_path = EXCLUDED.webhook_path,
  priority = EXCLUDED.priority,
  config = kshipra_core.survey_providers.config || EXCLUDED.config,
  updated_at = NOW();

INSERT INTO kshipra_core.survey_revenue_config (
  provider_id,
  user_percentage,
  bagbuddy_percentage,
  effective_from,
  created_by
)
SELECT
  id,
  70.00,
  30.00,
  CURRENT_DATE,
  'system'
FROM kshipra_core.survey_providers
WHERE name = 'tapjoy'
ON CONFLICT (provider_id, is_active, effective_from) DO NOTHING;

UPDATE kshipra_core.system_configurations
SET
  config_value = jsonb_set(
    COALESCE(config_value, '{}'::jsonb),
    '{tapjoy_enabled}',
    'true'::jsonb,
    true
  ),
  updated_at = CURRENT_TIMESTAMP,
  updated_by = 'system'
WHERE config_key = 'reward_methods_config'
  AND NOT (COALESCE(config_value, '{}'::jsonb) ? 'tapjoy_enabled');
