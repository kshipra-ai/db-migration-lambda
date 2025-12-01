-- V59__add_deactivated_review_status.sql
-- Add 'deactivated' value to campaign_review_status enum

-- Add new value to the enum type
ALTER TYPE kshipra_core.campaign_review_status ADD VALUE 'deactivated';

-- Add comment explaining the new status
COMMENT ON TYPE kshipra_core.campaign_review_status IS 'Review status for campaigns: pending (awaiting review), approved (active), declined (rejected), deactivated (inactive)';
