-- V142: Add ask_ai_enabled flag to campaigns table for admin control of Ask AI points feature
ALTER TABLE kshipra_core.campaigns
ADD COLUMN IF NOT EXISTS ask_ai_enabled BOOLEAN DEFAULT false;
