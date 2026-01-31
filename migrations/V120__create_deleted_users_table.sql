-- V118__create_deleted_users_table.sql
-- Creates deleted_users table for GDPR compliance (right to erasure)
-- This table archives deleted user data for legal retention requirements

CREATE TABLE IF NOT EXISTS kshipra_core.deleted_users (
    deleted_user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    original_user_id VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL,
    deletion_requested_at TIMESTAMP,
    deletion_reason TEXT,
    account_created_at TIMESTAMP NOT NULL,
    total_scans INTEGER DEFAULT 0,
    trees_planted INTEGER DEFAULT 0,
    final_cash_balance DECIMAL(10, 2) DEFAULT 0.00,
    deleted_by VARCHAR(50) NOT NULL,
    data_anonymization_level VARCHAR(50) NOT NULL DEFAULT 'full',
    allow_resignation_after TIMESTAMP,
    cognito_deleted BOOLEAN DEFAULT false,
    cognito_deletion_error TEXT,
    deleted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    retention_expires_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_deleted_users_original_user_id 
ON kshipra_core.deleted_users(original_user_id);

CREATE INDEX IF NOT EXISTS idx_deleted_users_email 
ON kshipra_core.deleted_users(email);

CREATE INDEX IF NOT EXISTS idx_deleted_users_deleted_at 
ON kshipra_core.deleted_users(deleted_at);

CREATE INDEX IF NOT EXISTS idx_deleted_users_retention_expires 
ON kshipra_core.deleted_users(retention_expires_at)
WHERE retention_expires_at IS NOT NULL;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON kshipra_core.deleted_users TO kshipra_admin;

-- Add comments for documentation
COMMENT ON TABLE kshipra_core.deleted_users IS 'Archives deleted user data for GDPR compliance and legal retention requirements';
COMMENT ON COLUMN kshipra_core.deleted_users.deleted_user_id IS 'Unique identifier for the deleted user record';
COMMENT ON COLUMN kshipra_core.deleted_users.original_user_id IS 'Original user_id from user_profile table';
COMMENT ON COLUMN kshipra_core.deleted_users.email IS 'User email address at time of deletion';
COMMENT ON COLUMN kshipra_core.deleted_users.deletion_requested_at IS 'When the user requested account deletion';
COMMENT ON COLUMN kshipra_core.deleted_users.deletion_reason IS 'User-provided reason for deletion';
COMMENT ON COLUMN kshipra_core.deleted_users.deleted_by IS 'Who initiated the deletion (user_request, admin, system)';
COMMENT ON COLUMN kshipra_core.deleted_users.data_anonymization_level IS 'Level of data anonymization applied (full, partial)';
COMMENT ON COLUMN kshipra_core.deleted_users.allow_resignation_after IS 'Date after which user can re-signup with same email';
COMMENT ON COLUMN kshipra_core.deleted_users.cognito_deleted IS 'Whether the user was successfully deleted from AWS Cognito';
COMMENT ON COLUMN kshipra_core.deleted_users.retention_expires_at IS 'Date when this archived record can be permanently deleted';
