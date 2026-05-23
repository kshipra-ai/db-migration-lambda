-- V172: Add location_id to user_profile for store (location-specific business) users.
-- Allows a store user's analytics to be scoped to their specific location.

ALTER TABLE kshipra_core.user_profile
    ADD COLUMN IF NOT EXISTS location_id UUID REFERENCES kshipra_core.partner_locations(location_id);

CREATE INDEX IF NOT EXISTS idx_user_profile_location_id ON kshipra_core.user_profile(location_id);
