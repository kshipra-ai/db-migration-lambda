-- Add columns to track actual CAD amount credited per ad provider per day
-- This allows accurate revenue/commission calculation even when rates change

ALTER TABLE kshipra_core.user_daily_ad_views
    ADD COLUMN google_ads_amount DECIMAL(10,4) NOT NULL DEFAULT 0,
    ADD COLUMN unity_ads_amount DECIMAL(10,4) NOT NULL DEFAULT 0,
    ADD COLUMN ironsource_ads_amount DECIMAL(10,4) NOT NULL DEFAULT 0;

-- Backfill historical rows using current payment_config rates (best approximation)
UPDATE kshipra_core.user_daily_ad_views
SET
    google_ads_amount = ad_count * COALESCE((SELECT google_ads_rate FROM kshipra_core.payment_config LIMIT 1), 0.40),
    unity_ads_amount = COALESCE(unity_ad_count, 0) * COALESCE((SELECT unity_ads_rate FROM kshipra_core.payment_config LIMIT 1), 0.40),
    ironsource_ads_amount = COALESCE(ironsource_ad_count, 0) * COALESCE((SELECT ironsource_ads_rate FROM kshipra_core.payment_config LIMIT 1), 0.20)
WHERE ad_count > 0 OR COALESCE(unity_ad_count, 0) > 0 OR COALESCE(ironsource_ad_count, 0) > 0;
