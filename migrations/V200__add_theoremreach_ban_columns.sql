-- TheoremReach sends a "ban" webhook event when they flag a user for fraud
-- (e.g. VPN/bot behavior). Previously this event was only logged, with no
-- way to act on it. These columns let us record the ban and block that
-- user from starting further TheoremReach surveys. Scoped to TheoremReach
-- only — other providers are unaffected.
ALTER TABLE kshipra_core.user_profile
    ADD COLUMN IF NOT EXISTS theoremreach_banned_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS theoremreach_ban_reason TEXT;
