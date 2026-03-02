-- V136: Create user_events table for mobile app engagement tracking
-- Stores fire-and-forget events from the mobile app (reward choice, survey start/complete, ad skip, qr scan)
-- Used by the admin analytics "Engagement" tab only — no brand/partner access

CREATE TABLE IF NOT EXISTS kshipra_core.user_events (
    id           SERIAL PRIMARY KEY,
    event        VARCHAR(100)             NOT NULL,
    user_id      VARCHAR(255),
    properties   JSONB                    NOT NULL DEFAULT '{}'::jsonb,
    created_at   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Index for fast aggregation by event name (used by GET /analytics/engagement)
CREATE INDEX IF NOT EXISTS idx_user_events_event
    ON kshipra_core.user_events (event);

-- Index for filtering by time windows (last 24h / last 7d queries)
CREATE INDEX IF NOT EXISTS idx_user_events_created_at
    ON kshipra_core.user_events (created_at DESC);

-- Index for per-user lookups if needed in future
CREATE INDEX IF NOT EXISTS idx_user_events_user_id
    ON kshipra_core.user_events (user_id)
    WHERE user_id IS NOT NULL;

-- Index for ad_type breakdown query: properties->>'ad_type' on reward_choice_selected rows
CREATE INDEX IF NOT EXISTS idx_user_events_ad_type
    ON kshipra_core.user_events ((properties->>'ad_type'))
    WHERE event = 'reward_choice_selected';

-- Comments
COMMENT ON TABLE kshipra_core.user_events IS 'Mobile app engagement events tracked via the analytics lambda. Admin-only visibility.';
COMMENT ON COLUMN kshipra_core.user_events.event IS 'Event name: reward_choice_selected, survey_started, survey_completed, ad_skipped, qr_scanned';
COMMENT ON COLUMN kshipra_core.user_events.user_id IS 'App user ID from JWT token (nullable for unauthenticated contexts)';
COMMENT ON COLUMN kshipra_core.user_events.properties IS 'Extra context: ad_type, survey_id, provider, reward_cents, etc.';
COMMENT ON COLUMN kshipra_core.user_events.created_at IS 'UTC timestamp when the event was recorded by the backend';
