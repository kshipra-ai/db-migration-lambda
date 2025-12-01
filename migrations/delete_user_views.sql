-- Delete user_deep_link_views entries for user_id = '114148314054633371259'

-- First, check what entries exist
SELECT 
    view_id,
    user_id,
    campaign_id,
    session_start_at,
    is_completed,
    actual_view_duration_seconds
FROM kshipra_core.user_deep_link_views
WHERE user_id = '114148314054633371259';

-- Delete the entries
DELETE FROM kshipra_core.user_deep_link_views
WHERE user_id = '114148314054633371259';

-- Verify deletion
SELECT COUNT(*) as remaining_count
FROM kshipra_core.user_deep_link_views
WHERE user_id = '114148314054633371259';
