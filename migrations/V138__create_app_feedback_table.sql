-- V138: Create app_feedback table to store user opinions about the app

CREATE TABLE IF NOT EXISTS kshipra_core.app_feedback (
    id           SERIAL PRIMARY KEY,
    user_id      VARCHAR(255) NOT NULL,
    rating       VARCHAR(10)  NOT NULL CHECK (rating IN ('like', 'dislike')),
    comment      TEXT,
    created_at   TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_feedback_user_id   ON kshipra_core.app_feedback (user_id);
CREATE INDEX IF NOT EXISTS idx_app_feedback_rating    ON kshipra_core.app_feedback (rating);
CREATE INDEX IF NOT EXISTS idx_app_feedback_created_at ON kshipra_core.app_feedback (created_at DESC);

-- Grant access to the lambda user
GRANT SELECT, INSERT ON kshipra_core.app_feedback TO kshipra_lambda;
GRANT USAGE, SELECT ON SEQUENCE kshipra_core.app_feedback_id_seq TO kshipra_lambda;
