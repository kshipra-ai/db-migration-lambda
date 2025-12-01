-- V88: Filter active campaigns to show only after user completes first view
-- Campaigns should only appear in user dashboard after earning first reward (completing min view duration)
-- This ensures users see only campaigns they've already engaged with and earned from

COMMENT ON TABLE kshipra_core.user_deep_link_views IS 
'Tracks user view sessions for campaigns. Campaigns appear in user dashboard only after user completes first view and earns reward (is_completed = true).';
