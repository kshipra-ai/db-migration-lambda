-- ============================================================
-- V161: Add presentation token to redemptions
-- ============================================================
-- Adds two columns supporting the two-layer QR security model.
-- When a customer opens the QR screen while logged in, a fresh
-- single-use presentation_token is generated server-side and
-- stored here. The displayed QR embeds both the original qr_token
-- and this presentation_token. On scan, the brand lambda validates
-- both tokens and then clears presentation_token so captured
-- photos/screenshots of the QR are permanently invalidated.
-- ============================================================

ALTER TABLE kshipra_core.redemptions
    ADD COLUMN IF NOT EXISTS presentation_token TEXT,
    ADD COLUMN IF NOT EXISTS presentation_token_generated_at TIMESTAMPTZ;

-- Partial index: only active (pending) redemptions that have a presentation token
-- need fast lookup during scan validation.
CREATE INDEX IF NOT EXISTS idx_redemptions_presentation_token
    ON kshipra_core.redemptions(presentation_token)
    WHERE presentation_token IS NOT NULL;

COMMENT ON COLUMN kshipra_core.redemptions.presentation_token IS
    'Single-use login-bound token. Generated when customer opens QR screen. '
    'Cleared on successful scan or when a new token is generated (screen reopen). '
    'NULL means no active QR session — cannot be scanned.';

COMMENT ON COLUMN kshipra_core.redemptions.presentation_token_generated_at IS
    'Timestamp when the current presentation_token was generated.';
