-- Replace per-week scratch card tracking with rolling batch tracking.
-- Each batch resets when a card is issued, so users can earn unlimited cards
-- (one per every N qualifying actions). The old weekly_progress table is kept
-- for historical data but is no longer written to by the application.

CREATE TABLE kshipra_core.scratch_card_batch_progress (
    user_id          TEXT        NOT NULL PRIMARY KEY,
    action_count     INT         NOT NULL DEFAULT 0,
    total_commission NUMERIC(12,4) NOT NULL DEFAULT 0,
    batch_num        INT         NOT NULL DEFAULT 0,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
