-- V163: Add TheoremReach provider and admin-controlled reward settings

ALTER TABLE kshipra_core.user_daily_ad_views
  ADD COLUMN IF NOT EXISTS theoremreach_survey_count INTEGER DEFAULT 0;

COMMENT ON COLUMN kshipra_core.user_daily_ad_views.theoremreach_survey_count IS
  'Number of TheoremReach reward center sessions opened today';

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
  'theoremreach',
  'TheoremReach',
  true,
  '/kshipra/surveys/theoremreach/credentials',
  'https://theoremreach.com',
  '/webhooks/theoremreach',
  90,
  '{
    "supportedCountries": ["US", "CA"],
    "rewardCenter": true,
    "requiresServerSideCallback": true
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
WHERE name = 'theoremreach'
ON CONFLICT (provider_id, is_active, effective_from) DO NOTHING;

INSERT INTO kshipra_core.system_configurations (
  config_key,
  config_value,
  description,
  is_active,
  created_at,
  updated_at,
  updated_by
)
VALUES (
  'daily_theoremreach_survey_limit',
  '{"limit": 10}'::jsonb,
  'Maximum number of TheoremReach reward center sessions a user can open per day',
  true,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP,
  'system'
)
ON CONFLICT (config_key) DO NOTHING;

INSERT INTO kshipra_core.system_configurations (
  config_key,
  config_value,
  description,
  is_active,
  created_at,
  updated_at,
  updated_by
)
VALUES (
  'reward_methods_config',
  '{"google_ads_enabled": true, "unity_ads_enabled": true, "ironsource_ads_enabled": true, "surveys_enabled": true, "tapjoy_enabled": true, "theoremreach_enabled": false}'::jsonb,
  'Controls which reward methods are visible to users in the mobile app',
  true,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP,
  'system'
)
ON CONFLICT (config_key) DO NOTHING;

UPDATE kshipra_core.system_configurations
SET
  config_value = jsonb_set(
    COALESCE(config_value, '{}'::jsonb),
    '{theoremreach_enabled}',
    'false'::jsonb,
    true
  ),
  updated_at = CURRENT_TIMESTAMP,
  updated_by = 'system'
WHERE config_key = 'reward_methods_config'
  AND NOT (COALESCE(config_value, '{}'::jsonb) ? 'theoremreach_enabled');
