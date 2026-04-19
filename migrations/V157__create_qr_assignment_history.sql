-- QR Code Assignment History
-- Tracks every link/unlink/reassign of a QR code to a store location.
-- Enables: viewing which stores a standee served, stats per assignment period,
-- and full audit trail of QR lifecycle.

CREATE TABLE IF NOT EXISTS kshipra_core.qr_assignment_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    qr_code_id VARCHAR(100) NOT NULL,
    location_id UUID NOT NULL,
    partner_id UUID NOT NULL,
    action VARCHAR(20) NOT NULL,  -- 'assigned', 'disabled', 'reassigned_from', 'reassigned_to', 'enabled'
    comment TEXT,
    performed_by TEXT,            -- admin email or system
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    unassigned_at TIMESTAMPTZ,    -- set when disabled or reassigned away
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_qr_assignment_history_qr_code ON kshipra_core.qr_assignment_history(qr_code_id);
CREATE INDEX idx_qr_assignment_history_location ON kshipra_core.qr_assignment_history(location_id);
CREATE INDEX idx_qr_assignment_history_action ON kshipra_core.qr_assignment_history(action);

-- Backfill existing active QR assignments into history
INSERT INTO kshipra_core.qr_assignment_history (qr_code_id, location_id, partner_id, action, comment, assigned_at)
SELECT lqc.qr_code_id, lqc.location_id, qc.partner_id, 'assigned', 'Backfilled from existing data', lqc.created_at
FROM kshipra_core.location_qr_codes lqc
JOIN kshipra_core.qr_campaigns qc ON qc.qr_code_id = lqc.qr_code_id
ON CONFLICT DO NOTHING;

-- Grant lambda user access
GRANT SELECT, INSERT, UPDATE ON kshipra_core.qr_assignment_history TO lambda_user;
