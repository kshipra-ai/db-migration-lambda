ALTER TABLE kshipra_core.user_surveys
    ADD COLUMN IF NOT EXISTS source_provider VARCHAR(50);

CREATE INDEX IF NOT EXISTS idx_user_surveys_source_provider
    ON kshipra_core.user_surveys(source_provider);
