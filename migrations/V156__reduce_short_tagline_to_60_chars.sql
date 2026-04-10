-- Reduce short_tagline column max length from 150 to 60 characters
-- Existing NULL values are unaffected; no data loss expected
ALTER TABLE kshipra_core.campaigns
ALTER COLUMN short_tagline TYPE VARCHAR(60);
