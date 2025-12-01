-- V17__create_lambda_tree_planting_user.sql
-- Create database user for tree-planting-service Lambda function

-- Create user with password (will be used in Lambda DATABASE_URL)
DO
$$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'lambda_tree_planting') THEN
        CREATE USER lambda_tree_planting WITH PASSWORD 'TreePlant#2025!SecurePass';
        RAISE NOTICE 'User lambda_tree_planting created';
    ELSE
        RAISE NOTICE 'User lambda_tree_planting already exists';
    END IF;
END
$$;

-- Grant connection to database (current database)
-- Note: GRANT CONNECT applies to the current database connection
-- This will work for both kshipra_dev and kshipra_production

-- Grant usage on schema
GRANT USAGE ON SCHEMA kshipra_core TO lambda_tree_planting;

-- Grant permissions on tree_planting_history table
GRANT SELECT, INSERT, UPDATE ON kshipra_core.tree_planting_history TO lambda_tree_planting;

-- Grant permission to use the sequence (for auto-increment ID)
GRANT USAGE, SELECT ON SEQUENCE kshipra_core.tree_planting_history_id_seq TO lambda_tree_planting;

-- Add comment for documentation
COMMENT ON ROLE lambda_tree_planting IS 'Lambda execution user for tree-planting-service - has limited permissions on tree_planting_history table only';
