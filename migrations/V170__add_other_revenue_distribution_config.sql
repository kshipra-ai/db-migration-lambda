-- V170: Add other_revenue_distribution_config table for ads/survey revenue splitting.
-- Covers Google Ads, Unity, IronSource, and Surveys ("other ways to earn").
-- Kshipra earns gross revenue from ad networks; this config controls the split.
--
-- payment_config rates were previously set as the user payout (70% of gross).
-- This migration converts them to gross rates (* 100/70) so the distribution
-- percentages apply correctly. Default config preserves existing user payouts.

CREATE TABLE IF NOT EXISTS kshipra_core.other_revenue_distribution_config (
    config_id       SERIAL PRIMARY KEY,
    user_percentage     NUMERIC(5,2) NOT NULL DEFAULT 70.00,
    business_percentage NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    kshipra_percentage  NUMERIC(5,2) NOT NULL DEFAULT 30.00,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_other_rev_sums_100 CHECK (
        ABS(user_percentage + business_percentage + kshipra_percentage - 100.0) < 0.01
    )
);

-- Initial row: matches existing implicit 70/30 split (business share = 0 until admin enables it)
INSERT INTO kshipra_core.other_revenue_distribution_config
    (user_percentage, business_percentage, kshipra_percentage, notes)
VALUES
    (70.00, 0.00, 30.00,
     'Initial default: 70% user, 0% business, 30% Kshipra — matches existing hardcoded split');

-- Convert payment_config rate columns from user-payout rates to gross rates.
-- Old rate = 70% of gross  →  gross = old_rate / 0.70 = old_rate * (100/70)
UPDATE kshipra_core.payment_config
SET
    google_ads_rate    = ROUND(google_ads_rate    * (100.0 / 70.0), 4),
    unity_ads_rate     = ROUND(unity_ads_rate     * (100.0 / 70.0), 4),
    ironsource_ads_rate = ROUND(ironsource_ads_rate * (100.0 / 70.0), 4);

GRANT SELECT, INSERT ON kshipra_core.other_revenue_distribution_config TO kshipra_admin;
GRANT USAGE, SELECT ON SEQUENCE kshipra_core.other_revenue_distribution_config_config_id_seq TO kshipra_admin;

COMMENT ON TABLE kshipra_core.other_revenue_distribution_config
    IS 'Controls how gross ad/survey revenue (Google Ads, Unity, IronSource, Surveys) is split between users, business partners, and Kshipra';
