-- V52: Make landing_pages.media_url and media_type optional (use campaign's media instead)

-- Drop NOT NULL constraint from media fields
ALTER TABLE kshipra_core.landing_pages 
ALTER COLUMN media_type DROP NOT NULL,
ALTER COLUMN media_url DROP NOT NULL;

-- Add comment explaining the change
COMMENT ON COLUMN kshipra_core.landing_pages.media_type IS 'Optional media type. If NULL, uses campaign.media_type';
COMMENT ON COLUMN kshipra_core.landing_pages.media_url IS 'Optional media URL. If NULL, uses campaign.media_url from S3';
