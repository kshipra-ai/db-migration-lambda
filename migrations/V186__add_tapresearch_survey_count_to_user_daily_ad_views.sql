ALTER TABLE kshipra_core.user_daily_ad_views
    ADD COLUMN IF NOT EXISTS tapresearch_survey_count INTEGER DEFAULT 0;
