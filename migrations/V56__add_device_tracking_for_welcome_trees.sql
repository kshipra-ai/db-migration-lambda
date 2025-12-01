-- V56: Add device tracking for welcome tree awards
-- Purpose: Track which devices have received welcome trees to prevent duplicates
-- One tree per device, even if app is uninstalled/reinstalled

CREATE TABLE IF NOT EXISTS kshipra_core.welcome_trees_awarded (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL UNIQUE,
    user_id VARCHAR(255) NOT NULL,
    awarded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Track which user received the tree on this device
    CONSTRAINT fk_user
        FOREIGN KEY(user_id) 
        REFERENCES kshipra_core.user_profile(user_id)
        ON DELETE CASCADE
);

-- Index for fast lookups by device_id
CREATE INDEX idx_welcome_trees_device_id ON kshipra_core.welcome_trees_awarded(device_id);

-- Index for user lookups (to see which devices a user has used)
CREATE INDEX idx_welcome_trees_user_id ON kshipra_core.welcome_trees_awarded(user_id);

-- Grant permissions to lambda user
GRANT SELECT, INSERT ON kshipra_core.welcome_trees_awarded TO kshipra_admin;
GRANT USAGE, SELECT ON SEQUENCE kshipra_core.welcome_trees_awarded_id_seq TO kshipra_admin;

-- Add comment
COMMENT ON TABLE kshipra_core.welcome_trees_awarded IS 'Tracks which devices have received welcome tree bonuses to prevent duplicate awards';
COMMENT ON COLUMN kshipra_core.welcome_trees_awarded.device_id IS 'Unique Android device ID (ANDROID_ID)';
COMMENT ON COLUMN kshipra_core.welcome_trees_awarded.user_id IS 'User who received the welcome tree on this device';
