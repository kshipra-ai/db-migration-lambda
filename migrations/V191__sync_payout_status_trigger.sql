-- V191: Auto-sync payout_status from status via trigger.
-- payout_status is redundant — status is the source of truth.
-- The trigger removes the need to set payout_status explicitly in application code.

CREATE OR REPLACE FUNCTION kshipra_core.sync_payout_status()
RETURNS TRIGGER AS $$
BEGIN
    NEW.payout_status = NEW.status;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_payout_status
BEFORE INSERT OR UPDATE ON kshipra_core.user_payouts
FOR EACH ROW EXECUTE FUNCTION kshipra_core.sync_payout_status();

-- Backfill any existing rows where they differ
UPDATE kshipra_core.user_payouts
SET payout_status = status
WHERE payout_status IS DISTINCT FROM status;
