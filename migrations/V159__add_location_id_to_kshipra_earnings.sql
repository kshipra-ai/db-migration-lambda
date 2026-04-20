-- V159: Add location_id to kshipra_earnings for location-based revenue attribution
-- Since QR scan is the gateway to all ad/survey content, every earning is attributable to a location

ALTER TABLE kshipra_core.kshipra_earnings ADD COLUMN location_id UUID;

CREATE INDEX idx_kshipra_earnings_location_id ON kshipra_core.kshipra_earnings(location_id);

GRANT SELECT, INSERT, UPDATE ON kshipra_core.kshipra_earnings TO kshipra_admin;
