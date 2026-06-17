-- Add qr_mode to track pool/store/bag lifecycle state for each QR code
ALTER TABLE kshipra_core.location_qr_codes
ADD COLUMN IF NOT EXISTS qr_mode VARCHAR(10) NOT NULL DEFAULT 'pool'
    CHECK (qr_mode IN ('pool', 'store', 'bag'));

-- Backfill: any QR currently linked to a location is in 'store' mode
UPDATE kshipra_core.location_qr_codes
SET qr_mode = 'store'
WHERE location_id IS NOT NULL
  AND is_active = true;

-- Allow bag QRs to exist in qr_campaigns without an owning partner
ALTER TABLE kshipra_core.qr_campaigns
    ALTER COLUMN partner_id DROP NOT NULL;
