-- V182: Allow NULL location_id and partner_id in qr_assignment_history
-- Bag QRs have no store location and no brand owner, so these columns
-- must be optional to record bag-assign / bag-unassign history events.
ALTER TABLE kshipra_core.qr_assignment_history
    ALTER COLUMN location_id DROP NOT NULL;

ALTER TABLE kshipra_core.qr_assignment_history
    ALTER COLUMN partner_id DROP NOT NULL;
