-- V144: Add redemption_enabled flag to campaigns table
-- Brands can enable/disable the in-app redemption QR option per campaign.
-- When disabled, the "Redeem" button is masked/hidden on the user ad box.

ALTER TABLE kshipra_core.campaigns
ADD COLUMN IF NOT EXISTS redemption_enabled BOOLEAN NOT NULL DEFAULT TRUE;

COMMENT ON COLUMN kshipra_core.campaigns.redemption_enabled IS
'When FALSE the in-app Redeem (QR) button is hidden for users viewing this campaign in the ad box.';
