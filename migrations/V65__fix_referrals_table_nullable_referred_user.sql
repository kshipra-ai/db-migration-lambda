-- Migration V65: Fix referrals table to allow null referred_user_id
-- This allows creating referral codes before they are used
-- referred_user_id is populated when the referral is completed

ALTER TABLE kshipra_core.referrals 
ALTER COLUMN referred_user_id DROP NOT NULL;

-- Update the unique constraint to handle null values properly
-- Drop the old constraint
ALTER TABLE kshipra_core.referrals 
DROP CONSTRAINT IF EXISTS unique_referral;

-- Add new unique constraint that allows multiple nulls
-- (A user can have multiple unused referral codes, but once used, the combination must be unique)
CREATE UNIQUE INDEX idx_unique_completed_referral 
ON kshipra_core.referrals (referrer_user_id, referred_user_id) 
WHERE referred_user_id IS NOT NULL;
