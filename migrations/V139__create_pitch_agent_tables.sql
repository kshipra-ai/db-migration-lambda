-- V139: Create pitch agent tables for multi-agent investor pitch preparation tool

-- CEO context entries: manual comments, insights from uploads, strategy notes
CREATE TABLE IF NOT EXISTS kshipra_core.pitch_ceo_context (
    id          SERIAL PRIMARY KEY,
    type        VARCHAR(20) NOT NULL CHECK (type IN ('comment','insight','correction','strategy','competitive','numbers')),
    content     TEXT NOT NULL,
    source      VARCHAR(50)  NOT NULL DEFAULT 'manual',
    media_id    VARCHAR(36),          -- UUID ref to pitch_uploads if derived from upload
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by  VARCHAR(50) NOT NULL DEFAULT 'ceo'
);

CREATE INDEX IF NOT EXISTS idx_pitch_context_created ON kshipra_core.pitch_ceo_context (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pitch_context_type    ON kshipra_core.pitch_ceo_context (type);

-- Media uploads: videos, images, documents uploaded by CEO
CREATE TABLE IF NOT EXISTS kshipra_core.pitch_uploads (
    id              VARCHAR(36)  PRIMARY KEY,  -- UUID assigned at upload time
    filename        TEXT         NOT NULL,
    original_name   TEXT         NOT NULL,
    mime_type       VARCHAR(100) NOT NULL,
    size_bytes      INTEGER      NOT NULL,
    storage_path    TEXT         NOT NULL,
    description     TEXT,
    analysis        TEXT,                      -- GPT-4o vision/audio analysis result
    insights        TEXT,                      -- Extracted KB-relevant insights
    processed       BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by      VARCHAR(50)  NOT NULL DEFAULT 'ceo'
);

CREATE INDEX IF NOT EXISTS idx_pitch_uploads_created ON kshipra_core.pitch_uploads (created_at DESC);

-- Custom investor questions added by CEO/admin
CREATE TABLE IF NOT EXISTS kshipra_core.pitch_custom_questions (
    id          SERIAL PRIMARY KEY,
    question    TEXT        NOT NULL,
    category    VARCHAR(50) NOT NULL DEFAULT 'custom',
    priority    INTEGER     NOT NULL DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    notes       TEXT,
    active      BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP   NOT NULL DEFAULT NOW(),
    created_by  VARCHAR(50) NOT NULL DEFAULT 'ceo'
);

CREATE INDEX IF NOT EXISTS idx_pitch_questions_active ON kshipra_core.pitch_custom_questions (active, priority);

-- Full debate sessions with judge verdict and pitch-readiness score
CREATE TABLE IF NOT EXISTS kshipra_core.pitch_debate_sessions (
    id            SERIAL PRIMARY KEY,
    session_id    VARCHAR(36)  NOT NULL UNIQUE,  -- UUID
    question      TEXT         NOT NULL,
    rounds        INTEGER      NOT NULL DEFAULT 0,
    final_score   NUMERIC(4,2),
    status        VARCHAR(20)  NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','running','complete','error')),
    result_json   TEXT,
    judge_verdict TEXT,
    pitch_ready   VARCHAR(30),
    triggered_by  VARCHAR(50)  DEFAULT 'ceo',
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    completed_at  TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_pitch_sessions_created    ON kshipra_core.pitch_debate_sessions (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pitch_sessions_session_id ON kshipra_core.pitch_debate_sessions (session_id);

-- Individual rounds within a debate session
CREATE TABLE IF NOT EXISTS kshipra_core.pitch_debate_rounds (
    id              SERIAL PRIMARY KEY,
    session_id      VARCHAR(36)   NOT NULL REFERENCES kshipra_core.pitch_debate_sessions(session_id) ON DELETE CASCADE,
    round_number    INTEGER       NOT NULL,
    pitcher_answer  TEXT          NOT NULL,
    critic_review   TEXT          NOT NULL,
    score           NUMERIC(4,2)  NOT NULL,
    UNIQUE (session_id, round_number)
);

CREATE INDEX IF NOT EXISTS idx_pitch_rounds_session ON kshipra_core.pitch_debate_rounds (session_id);

-- Knowledge base change log (audit trail for KB updates)
CREATE TABLE IF NOT EXISTS kshipra_core.pitch_kb_changes (
    id          SERIAL PRIMARY KEY,
    summary     TEXT        NOT NULL,
    category    VARCHAR(50) NOT NULL,
    changed_by  VARCHAR(50) NOT NULL DEFAULT 'ceo',
    git_commit  VARCHAR(40),
    created_at  TIMESTAMP   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pitch_kb_changes_created ON kshipra_core.pitch_kb_changes (created_at DESC);

-- Grant access to the lambda DB user
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.pitch_ceo_context      TO kshipra_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.pitch_uploads           TO kshipra_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.pitch_custom_questions  TO kshipra_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.pitch_debate_sessions   TO kshipra_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.pitch_debate_rounds     TO kshipra_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON kshipra_core.pitch_kb_changes        TO kshipra_admin;

GRANT USAGE, SELECT ON SEQUENCE kshipra_core.pitch_ceo_context_id_seq      TO kshipra_admin;
GRANT USAGE, SELECT ON SEQUENCE kshipra_core.pitch_custom_questions_id_seq TO kshipra_admin;
GRANT USAGE, SELECT ON SEQUENCE kshipra_core.pitch_debate_sessions_id_seq  TO kshipra_admin;
GRANT USAGE, SELECT ON SEQUENCE kshipra_core.pitch_debate_rounds_id_seq    TO kshipra_admin;
GRANT USAGE, SELECT ON SEQUENCE kshipra_core.pitch_kb_changes_id_seq       TO kshipra_admin;
