-- Tracks each user's action count and accumulated Kshipra commission per ISO week.
-- Resets naturally by week_start (Monday). One row per user per week.
CREATE TABLE IF NOT EXISTS kshipra_core.scratch_card_weekly_progress (
    id                      SERIAL PRIMARY KEY,
    user_id                 VARCHAR(255) NOT NULL,
    week_start              DATE NOT NULL,          -- always the Monday of that week
    action_count            INT NOT NULL DEFAULT 0,
    total_commission        NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    scratch_card_issued     BOOLEAN NOT NULL DEFAULT false,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, week_start)
);

CREATE INDEX IF NOT EXISTS idx_scratch_weekly_user_week
    ON kshipra_core.scratch_card_weekly_progress (user_id, week_start);
