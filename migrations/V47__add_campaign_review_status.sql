-- V47__add_campaign_review_status.sql
-- Add campaign review/approval workflow fields

-- Add review status enum type
CREATE TYPE kshipra_core.campaign_review_status AS ENUM ('pending', 'approved', 'declined');

-- Add review workflow columns to campaigns table
ALTER TABLE kshipra_core.campaigns 
ADD COLUMN review_status kshipra_core.campaign_review_status NOT NULL DEFAULT 'approved',
ADD COLUMN reviewed_by TEXT REFERENCES kshipra_core.user_profile(user_id),
ADD COLUMN reviewed_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN review_notes TEXT;

-- Create index for filtering by review status
CREATE INDEX idx_campaigns_review_status ON kshipra_core.campaigns(review_status);

-- Create index for approved and active campaigns (most common query)
CREATE INDEX idx_campaigns_approved_active ON kshipra_core.campaigns(review_status, is_active) 
WHERE review_status = 'approved' AND is_active = true;

-- Update existing campaigns to be approved (backward compatibility)
-- All existing campaigns are assumed to be already reviewed and approved
UPDATE kshipra_core.campaigns 
SET review_status = 'approved', 
    reviewed_at = created_at,
    review_notes = 'Auto-approved during migration'
WHERE review_status = 'approved'; -- This is already the default

-- Add comment to document the review workflow
COMMENT ON COLUMN kshipra_core.campaigns.review_status IS 'Campaign review status: pending (awaiting admin review), approved (visible to users), declined (rejected by admin)';
COMMENT ON COLUMN kshipra_core.campaigns.reviewed_by IS 'User ID of admin who reviewed the campaign';
COMMENT ON COLUMN kshipra_core.campaigns.reviewed_at IS 'Timestamp when campaign was reviewed';
COMMENT ON COLUMN kshipra_core.campaigns.review_notes IS 'Admin notes about review decision';

-- Grant permissions for review columns
GRANT SELECT, UPDATE ON kshipra_core.campaigns TO kshipra_admin;
