-- V132__add_reward_rate_to_partners.sql
-- Add reward_rate and max_daily_rewards columns to partners table.
-- These columns are used by generateLocationQRCode in partner-lambda to determine
-- how many points to award per scan and the daily scan cap per location.
-- The columns may already exist on instances where V11 ran fully; using IF NOT EXISTS is safe.

ALTER TABLE kshipra_core.partners
    ADD COLUMN IF NOT EXISTS reward_rate INTEGER NOT NULL DEFAULT 25,
    ADD COLUMN IF NOT EXISTS max_daily_rewards INTEGER NOT NULL DEFAULT 5;

COMMENT ON COLUMN kshipra_core.partners.reward_rate IS 'Points awarded per QR scan at this partner location. Default 25.';
COMMENT ON COLUMN kshipra_core.partners.max_daily_rewards IS 'Maximum number of rewarded scans per day per location QR code. Default 5.';
