-- V162: Enforce at most one active QR code per store location.
--
-- The partner-lambda already treats a location as having a single active QR.
-- This index makes that rule database-enforced while still allowing disabled
-- historical QR assignments to remain attached for audit/reuse workflows.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM kshipra_core.location_qr_codes
        WHERE is_active = true
        GROUP BY location_id
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Cannot add one-active-QR constraint: duplicate active location QR codes exist';
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_location_qr_codes_one_active_per_location
    ON kshipra_core.location_qr_codes(location_id)
    WHERE is_active = true;

