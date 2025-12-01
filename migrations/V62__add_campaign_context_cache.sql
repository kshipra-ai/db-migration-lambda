-- V58: Add campaign_context column to cache scraped website content
-- Purpose: Avoid re-scraping URLs on every message (performance optimization)

ALTER TABLE kshipra_core.campaign_chat_sessions 
ADD COLUMN IF NOT EXISTS campaign_context TEXT;

COMMENT ON COLUMN kshipra_core.campaign_chat_sessions.campaign_context IS 'Cached scraped content from campaign URL (scraped once at session start)';
