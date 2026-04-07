-- Add configurable USD to CAD exchange rate
-- Google/Unity/IronSource ad networks pay in USD; tree planting costs $1 USD
-- All internal amounts are in CAD, so we need a conversion rate

ALTER TABLE kshipra_core.payment_config
    ADD COLUMN usd_cad_rate DECIMAL(6,4) NOT NULL DEFAULT 1.3700;
