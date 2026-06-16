-- V180: QR code pool support
-- Allows generating QR codes in advance without assigning them to a store location.
-- Admin can generate a batch of QRs, then link each to a store when ready.
-- qr_number provides a human-readable identifier displayed below the physical QR standee.

-- 1. Allow location_id to be NULL (pool QRs have no location yet)
ALTER TABLE kshipra_core.location_qr_codes
    ALTER COLUMN location_id DROP NOT NULL;

-- 2. Add qr_number SERIAL for human-readable identification (auto-increments per row)
ALTER TABLE kshipra_core.location_qr_codes
    ADD COLUMN IF NOT EXISTS qr_number SERIAL;

-- 3. Drop the old partial unique index (it assumed location_id is always set)
DROP INDEX IF EXISTS kshipra_core.idx_location_qr_codes_one_active_per_location;

-- 4. Recreate the one-active-per-location constraint, but only when location_id IS NOT NULL.
--    Pool QRs (location_id IS NULL) are always is_active=false so they never conflict.
CREATE UNIQUE INDEX IF NOT EXISTS idx_location_qr_codes_one_active_per_location
    ON kshipra_core.location_qr_codes(location_id)
    WHERE is_active = true AND location_id IS NOT NULL;
