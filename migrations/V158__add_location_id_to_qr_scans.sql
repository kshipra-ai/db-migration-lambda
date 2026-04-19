-- Add location_id to qr_scans so we track which store location each scan came from.
-- This is nullable because not all QR codes are location-based (some are standalone campaigns).

ALTER TABLE kshipra_core.qr_scans ADD COLUMN IF NOT EXISTS location_id UUID;

CREATE INDEX IF NOT EXISTS idx_qr_scans_location ON kshipra_core.qr_scans(location_id);
