-- V133__create_ad_transactions_table.sql
-- Creates the kshipra_core.transactions table used by ad handlers as an audit log.
-- All three ad handlers (Unity, Google/AdMob, IronSource) INSERT into this table
-- after a successful ad view. The table is write-only from the lambda side;
-- no user-facing query reads from it, but it is critical for ad revenue auditing.
--
-- Transaction types written:
--   unity_ad_view        - Unity rewarded ad watched
--   google_ad_pending    - Google AdMob rewarded ad watched
--   ironsource_ad_pending - IronSource rewarded ad watched

CREATE TABLE IF NOT EXISTS kshipra_core.transactions (
    transaction_id   UUID         PRIMARY KEY,
    user_id          UUID         NOT NULL,
    points           INTEGER      NOT NULL DEFAULT 0,
    transaction_type VARCHAR(64)  NOT NULL,
    description      TEXT,
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_user_id
    ON kshipra_core.transactions (user_id);

CREATE INDEX IF NOT EXISTS idx_transactions_created_at
    ON kshipra_core.transactions (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_transactions_type
    ON kshipra_core.transactions (transaction_type);

COMMENT ON TABLE kshipra_core.transactions IS
    'Audit log for ad view events (Unity, Google AdMob, IronSource). '
    'Each row represents one rewarded ad watched by a user. '
    'Payment is calculated at month end from user_daily_ad_views, not from this table.';

COMMENT ON COLUMN kshipra_core.transactions.transaction_type IS
    'Type of ad event: unity_ad_view | google_ad_pending | ironsource_ad_pending';

COMMENT ON COLUMN kshipra_core.transactions.points IS
    'For Unity/Google: always 0 (payment via pending_balance). '
    'For IronSource: pending_amount * 1000 (milli-cents).';

-- Grant access to the lambda DB user (same pattern as other migrations)
GRANT INSERT, SELECT ON kshipra_core.transactions TO kshipra_admin;
