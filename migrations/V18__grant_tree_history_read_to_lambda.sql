-- V18__grant_tree_history_read_to_lambda.sql
-- Grant read permissions on tree_planting_history table to kshipra_admin role
-- This allows rewards-lambda to query tree contribution data when users login

-- Grant SELECT permission on tree_planting_history table
GRANT SELECT ON kshipra_core.tree_planting_history TO kshipra_admin;

COMMENT ON ROLE kshipra_admin IS 'Lambda execution user for rewards-lambda - has access to user_profile and tree_planting_history tables';
