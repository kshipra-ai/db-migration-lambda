-- V134: Add IronSource Ads settlement support to payment_config table
-- ironsource_ad_count column already exists in user_daily_ad_views (added in V107)
-- This adds the settlement schedule date and rate columns for the cron job

ALTER TABLE kshipra_core.payment_config
ADD COLUMN IF NOT EXISTS ironsource_ads_date INTEGER NOT NULL DEFAULT 22 CHECK (ironsource_ads_date >= 1 AND ironsource_ads_date <= 31),
ADD COLUMN IF NOT EXISTS ironsource_ads_rate NUMERIC(10, 4) NOT NULL DEFAULT 0.0070 CHECK (ironsource_ads_rate > 0);

-- Update the existing config row to include defaults
UPDATE kshipra_core.payment_config
SET
    ironsource_ads_date = 22,
    ironsource_ads_rate = 0.0070
WHERE ironsource_ads_date IS NULL OR ironsource_ads_rate IS NULL;

-- Add comments
COMMENT ON COLUMN kshipra_core.payment_config.ironsource_ads_date IS 'Day of month to run IronSource Ads settlement (1-31)';
COMMENT ON COLUMN kshipra_core.payment_config.ironsource_ads_rate IS 'Payment rate per IronSource ad view in CAD';
