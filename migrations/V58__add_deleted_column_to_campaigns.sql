-- V58__add_deleted_column_to_campaigns.sql
-- Add deleted column to campaigns table for soft delete functionality

-- Add deleted column
ALTER TABLE kshipra_core.campaigns 
ADD COLUMN deleted BOOLEAN NOT NULL DEFAULT false;

-- Add index for better query performance when filtering out deleted campaigns
CREATE INDEX idx_campaigns_deleted ON kshipra_core.campaigns(deleted) WHERE deleted = false;

-- Add comment to explain the column
COMMENT ON COLUMN kshipra_core.campaigns.deleted IS 'Soft delete flag - when true, campaign should not appear in lists but remains in DB for history';
