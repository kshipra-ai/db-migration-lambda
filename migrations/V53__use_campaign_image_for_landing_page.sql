-- Remove external Unsplash image from landing page
-- Landing page will now use the campaign's S3 image via COALESCE in Lambda query

UPDATE kshipra_core.landing_pages 
SET 
    media_url = NULL,
    media_type = NULL,
    cta_url = NULL
WHERE campaign_id = '991fbda5-bff2-4907-a349-3f0fff7c2397';

COMMENT ON TABLE kshipra_core.landing_pages IS 'Landing pages for campaigns. media_url/media_type can be NULL to use campaign media from S3';
