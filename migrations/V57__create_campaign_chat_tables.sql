-- V57: Create campaign chat tables for AI chatbot feature
-- Purpose: Store chat sessions and messages between users and AI about campaigns

-- Chat sessions table
CREATE TABLE IF NOT EXISTS kshipra_core.campaign_chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP WITH TIME ZONE,
    s3_backup_url TEXT,
    message_count INTEGER DEFAULT 0,
    
    -- Foreign keys
    CONSTRAINT fk_campaign
        FOREIGN KEY(campaign_id) 
        REFERENCES kshipra_core.campaigns(campaign_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_user
        FOREIGN KEY(user_id) 
        REFERENCES kshipra_core.user_profile(user_id)
        ON DELETE CASCADE
);

-- Chat messages table
CREATE TABLE IF NOT EXISTS kshipra_core.campaign_chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign key
    CONSTRAINT fk_session
        FOREIGN KEY(session_id) 
        REFERENCES kshipra_core.campaign_chat_sessions(id)
        ON DELETE CASCADE
);

-- Indexes for performance
CREATE INDEX idx_chat_sessions_campaign ON kshipra_core.campaign_chat_sessions(campaign_id);
CREATE INDEX idx_chat_sessions_user ON kshipra_core.campaign_chat_sessions(user_id);
CREATE INDEX idx_chat_sessions_started ON kshipra_core.campaign_chat_sessions(started_at DESC);
CREATE INDEX idx_chat_messages_session ON kshipra_core.campaign_chat_messages(session_id);
CREATE INDEX idx_chat_messages_created ON kshipra_core.campaign_chat_messages(created_at);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON kshipra_core.campaign_chat_sessions TO kshipra_admin;
GRANT SELECT, INSERT ON kshipra_core.campaign_chat_messages TO kshipra_admin;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA kshipra_core TO kshipra_admin;

-- Comments
COMMENT ON TABLE kshipra_core.campaign_chat_sessions IS 'Stores AI chat sessions between users and campaigns';
COMMENT ON TABLE kshipra_core.campaign_chat_messages IS 'Stores individual messages within chat sessions';
COMMENT ON COLUMN kshipra_core.campaign_chat_sessions.s3_backup_url IS 'URL to S3 backup of full conversation JSON';
COMMENT ON COLUMN kshipra_core.campaign_chat_messages.role IS 'Message sender: user (customer), assistant (AI), or system (context)';
