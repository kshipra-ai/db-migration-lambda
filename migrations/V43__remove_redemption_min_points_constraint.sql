-- V43__remove_redemption_min_points_constraint.sql
-- Change the hardcoded 100-point minimum constraint to 1 point
-- This aligns with business requirement to allow small redemptions
-- Minimum points validation is enforced in Lambda code for flexibility

-- Drop the old 100-point minimum constraint
ALTER TABLE kshipra_core.redemptions 
DROP CONSTRAINT IF EXISTS chk_redemption_points_min;

-- Add new 1-point minimum constraint (non-zero positive value)
ALTER TABLE kshipra_core.redemptions 
ADD CONSTRAINT chk_redemption_points_min CHECK (points_redeemed >= 1);

-- Add a comment explaining the constraint
COMMENT ON TABLE kshipra_core.redemptions IS 'One-time use QR codes for users to redeem points at brand stores. Minimum 1 point required (enforced by DB constraint). Additional business rules enforced in Lambda code.';

-- Note: We keep chk_redemption_points_positive (points > 0) as redundant safety
-- The new constraint (points >= 1) is effectively the same as (points > 0) for integers
