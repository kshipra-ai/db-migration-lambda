-- V167: Attribute user redemption credits to a business location when available.
-- Business location analytics can then separate:
-- 1) customer redemption points spent at the business
-- 2) QR host/business revenue share from scan engagement

ALTER TABLE kshipra_core.brand_credits
    ADD COLUMN IF NOT EXISTS location_id UUID REFERENCES kshipra_core.partner_locations(location_id);

CREATE INDEX IF NOT EXISTS idx_brand_credits_location_id
    ON kshipra_core.brand_credits(location_id);

CREATE INDEX IF NOT EXISTS idx_brand_credits_partner_location
    ON kshipra_core.brand_credits(partner_id, location_id);

COMMENT ON COLUMN kshipra_core.brand_credits.location_id IS
'Business location where the customer redemption was scanned. Nullable for historical records and partners without location attribution.';
