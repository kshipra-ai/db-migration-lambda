-- V87__rename_bag_volume_to_view_count.sql
-- Rename bag_volume to view_count as campaigns are now based on views, not bag sponsorship

-- Drop the old constraint
ALTER TABLE kshipra_core.campaigns 
DROP CONSTRAINT IF EXISTS check_positive_bag_volume;

-- Drop the old index
DROP INDEX IF EXISTS kshipra_core.idx_campaigns_bag_volume;

-- Rename the column
ALTER TABLE kshipra_core.campaigns 
RENAME COLUMN bag_volume TO view_count;

-- Add new constraint for view_count
ALTER TABLE kshipra_core.campaigns 
ADD CONSTRAINT check_positive_view_count CHECK (view_count IS NULL OR view_count > 0);

-- Add new index for view_count
CREATE INDEX IF NOT EXISTS idx_campaigns_view_count ON kshipra_core.campaigns(view_count) WHERE view_count IS NOT NULL;

-- Update column comment
COMMENT ON COLUMN kshipra_core.campaigns.view_count IS 'Target number of views for this campaign (brands pay for views)';
