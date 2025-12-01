-- Migration V72: Add soft delete support to user_profile table
-- Allows tracking deleted users and preventing duplicate signups with reset data

-- Add deleted status columns
ALTER TABLE kshipra_core.user_profile 
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS deleted_by VARCHAR(255),
ADD COLUMN IF NOT EXISTS deletion_reason TEXT;

-- Create index for deleted users
CREATE INDEX IF NOT EXISTS idx_user_profile_deleted 
ON kshipra_core.user_profile(is_deleted, email);

-- Create index for active users (most common query)
CREATE INDEX IF NOT EXISTS idx_user_profile_active 
ON kshipra_core.user_profile(email, is_deleted) WHERE is_deleted = false;

-- Add comments
COMMENT ON COLUMN kshipra_core.user_profile.is_deleted IS 'Soft delete flag - user account is deleted but record preserved for history';
COMMENT ON COLUMN kshipra_core.user_profile.deleted_at IS 'Timestamp when user was deleted';
COMMENT ON COLUMN kshipra_core.user_profile.deleted_by IS 'Admin user_id who deleted the user';
COMMENT ON COLUMN kshipra_core.user_profile.deletion_reason IS 'Reason for deletion (admin notes)';

-- Grant permissions (lambda needs update permission for soft delete)
GRANT SELECT, UPDATE ON kshipra_core.user_profile TO lambda_tree_planting;
