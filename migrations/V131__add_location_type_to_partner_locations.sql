-- V131: Add location_type to partner_locations
-- Allows distinguishing between locations that carry BagBuddy bags vs standees (or both)
-- Users can find nearby stores/restaurants from the mobile app filtered by type

ALTER TABLE kshipra_core.partner_locations
    ADD COLUMN IF NOT EXISTS location_type VARCHAR(20) NOT NULL DEFAULT 'bags'
        CHECK (location_type IN ('bags', 'standees', 'both'));

-- Update existing rows explicitly (redundant with DEFAULT but explicit is safer)
UPDATE kshipra_core.partner_locations
    SET location_type = 'bags'
    WHERE location_type IS NULL;

-- Index for filtering by type in the public locations query
CREATE INDEX IF NOT EXISTS idx_partner_locations_type
    ON kshipra_core.partner_locations(location_type, is_active);

COMMENT ON COLUMN kshipra_core.partner_locations.location_type IS
    'bags = BagBuddy bags available here | standees = promo standee here | both = bags and standee';
