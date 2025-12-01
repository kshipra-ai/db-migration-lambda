-- V45: Change redemption model to weekly limits per brand
-- Remove per-user allocation concept, use weekly limits instead

-- Drop the max_redeemable_points column (not needed)
ALTER TABLE kshipra_core.user_brand_allocations
DROP COLUMN IF EXISTS max_redeemable_points;

-- Add weekly reset tracking
ALTER TABLE kshipra_core.user_brand_allocations
ADD COLUMN IF NOT EXISTS weekly_reset_date DATE NOT NULL DEFAULT CURRENT_DATE;

-- Rename column for clarity
ALTER TABLE kshipra_core.user_brand_allocations
RENAME COLUMN total_points_redeemed TO weekly_points_redeemed;

-- Add comment explaining the new model
COMMENT ON COLUMN kshipra_core.user_brand_allocations.weekly_points_redeemed IS 
'Total points redeemed this week. Resets to 0 every 7 days from weekly_reset_date. Max per week = partners.max_redemption_per_transaction';

COMMENT ON COLUMN kshipra_core.user_brand_allocations.weekly_reset_date IS 
'Date when weekly_points_redeemed was last reset. If > 7 days ago, reset to 0 and update this date';

COMMENT ON TABLE kshipra_core.user_brand_allocations IS 
'Tracks weekly redemption limits per user per brand. Users can redeem up to partners.max_redemption_per_transaction points per brand per week. Resets every 7 days.';
