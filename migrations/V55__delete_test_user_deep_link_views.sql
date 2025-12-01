-- Delete user_deep_link_views entries for test user that's causing issues
-- This is a data cleanup migration

DELETE FROM kshipra_core.user_deep_link_views
WHERE user_id = '114148314054633371259';

-- Log the deletion
DO $$
DECLARE
    deleted_count INTEGER;
BEGIN
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % rows from user_deep_link_views for user_id 114148314054633371259', deleted_count;
END $$;
