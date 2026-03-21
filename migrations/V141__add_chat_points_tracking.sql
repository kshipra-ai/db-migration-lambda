-- V141: Add valid question count and points tracking to campaign chat sessions
-- Supports Ask AI points feature: +10 points per brand after 10 valid questions in a session

ALTER TABLE kshipra_core.campaign_chat_sessions
ADD COLUMN IF NOT EXISTS valid_question_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS points_awarded BOOLEAN DEFAULT false;
