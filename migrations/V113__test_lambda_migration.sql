-- Test migration to verify Lambda is working
-- This creates a simple test table that can be verified

CREATE TABLE IF NOT EXISTS kshipra_core.lambda_migration_test (
    id SERIAL PRIMARY KEY,
    test_message VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert a test record
INSERT INTO kshipra_core.lambda_migration_test (test_message)
VALUES ('Lambda migration V113 applied successfully on 2026-01-11');

COMMENT ON TABLE kshipra_core.lambda_migration_test IS 'Test table to verify production Lambda migrations are working';
