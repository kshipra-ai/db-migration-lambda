-- V104: Add postal_code and date_of_birth to user_profile for CPX demographic targeting

-- Add postal_code column for CPX demographic targeting (subid3)
ALTER TABLE kshipra_core.user_profile 
ADD COLUMN IF NOT EXISTS postal_code VARCHAR(20);

-- Add date_of_birth column for CPX demographic targeting (subid1 - age calculation)
ALTER TABLE kshipra_core.user_profile 
ADD COLUMN IF NOT EXISTS date_of_birth DATE;

-- Add comment for documentation
COMMENT ON COLUMN kshipra_core.user_profile.postal_code IS 'Postal/ZIP code for CPX Research demographic targeting (subid3)';
COMMENT ON COLUMN kshipra_core.user_profile.date_of_birth IS 'Date of birth for CPX Research age targeting (subid1). Must be 18+ for survey eligibility.';
