-- V48__change_campaign_default_to_pending.sql
-- Change default review_status to 'pending' for new campaigns

-- Drop the existing default
ALTER TABLE kshipra_core.campaigns 
ALTER COLUMN review_status DROP DEFAULT;

-- Set new default to 'pending' for newly created campaigns
ALTER TABLE kshipra_core.campaigns 
ALTER COLUMN review_status SET DEFAULT 'pending';

-- Add comment explaining the change
COMMENT ON COLUMN kshipra_core.campaigns.review_status IS 'Campaign review status: pending (awaiting admin review - DEFAULT for new campaigns), approved (visible to users), declined (rejected by admin)';

-- Note: Existing campaigns remain 'approved' (they were already set in V47)
-- Only new campaigns will default to 'pending' going forward
