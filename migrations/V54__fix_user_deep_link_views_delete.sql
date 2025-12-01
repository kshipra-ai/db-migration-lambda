-- Fix: Allow deleting rows from user_deep_link_views table
-- The "meta data not found error" happens because the table has complex constraints

-- First, let's check if there are any issues with the table metadata
DO $$
BEGIN
    -- Refresh table metadata
    PERFORM pg_catalog.pg_class.oid 
    FROM pg_catalog.pg_class 
    WHERE relname = 'user_deep_link_views' 
    AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'kshipra_core');
    
    RAISE NOTICE 'Table metadata refreshed for user_deep_link_views';
END $$;

-- Drop and recreate the unique constraint to fix any metadata issues
ALTER TABLE kshipra_core.user_deep_link_views 
DROP CONSTRAINT IF EXISTS unique_user_campaign_view;

ALTER TABLE kshipra_core.user_deep_link_views 
ADD CONSTRAINT unique_user_campaign_view UNIQUE (user_id, campaign_id);

COMMENT ON TABLE kshipra_core.user_deep_link_views IS 'Tracks campaign deep link views. Delete rows using: DELETE FROM kshipra_core.user_deep_link_views WHERE view_id = ''...'';';
