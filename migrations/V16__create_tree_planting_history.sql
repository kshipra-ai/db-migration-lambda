-- V16__create_tree_planting_history.sql
-- Create table for tracking tree planting history via tree-planting-service Lambda
-- This table stores the history of tree planting requests sent to DigitalHumani API

-- Create tree_planting_history table
CREATE TABLE IF NOT EXISTS kshipra_core.tree_planting_history (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    planted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    tree_count INTEGER NOT NULL CHECK (tree_count > 0),
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'completed', 'failed')),
    provider_name VARCHAR(50) NOT NULL DEFAULT 'DigitalHumani',
    provider_uuid VARCHAR(255), -- UUID from DigitalHumani API response
    user_email VARCHAR(255),
    trees_earned_total INTEGER, -- Total trees user has earned at time of planting
    rewards_earned INTEGER, -- Rewards points that triggered this planting
    error_message TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Add indexes for efficient queries
CREATE INDEX idx_tree_planting_user_id ON kshipra_core.tree_planting_history(user_id);
CREATE INDEX idx_tree_planting_status ON kshipra_core.tree_planting_history(status);
CREATE INDEX idx_tree_planting_provider_uuid ON kshipra_core.tree_planting_history(provider_uuid) WHERE provider_uuid IS NOT NULL;
CREATE INDEX idx_tree_planting_planted_at ON kshipra_core.tree_planting_history(planted_at DESC);
CREATE INDEX idx_tree_planting_user_status ON kshipra_core.tree_planting_history(user_id, status);

-- Add comments for documentation
COMMENT ON TABLE kshipra_core.tree_planting_history IS 'Tracks tree planting history from tree-planting-service Lambda via DigitalHumani API';
COMMENT ON COLUMN kshipra_core.tree_planting_history.user_id IS 'User identifier from rewards-lambda';
COMMENT ON COLUMN kshipra_core.tree_planting_history.planted_at IS 'Timestamp when planting was initiated';
COMMENT ON COLUMN kshipra_core.tree_planting_history.tree_count IS 'Number of trees planted in this request';
COMMENT ON COLUMN kshipra_core.tree_planting_history.status IS 'pending: awaiting API response, completed: successfully planted, failed: API error';
COMMENT ON COLUMN kshipra_core.tree_planting_history.provider_name IS 'Tree planting provider (DigitalHumani)';
COMMENT ON COLUMN kshipra_core.tree_planting_history.provider_uuid IS 'Unique identifier from DigitalHumani API for tracking';
COMMENT ON COLUMN kshipra_core.tree_planting_history.error_message IS 'Error details if status is failed';

-- Grant permissions (adjust based on your Lambda execution role)
-- GRANT SELECT, INSERT, UPDATE ON kshipra_core.tree_planting_history TO lambda_execution_role;
-- GRANT USAGE, SELECT ON SEQUENCE kshipra_core.tree_planting_history_id_seq TO lambda_execution_role;
