CREATE TABLE IF NOT EXISTS kshipra_core.email_blast_history (
    id SERIAL PRIMARY KEY,
    subject TEXT NOT NULL,
    recipient_count INT DEFAULT 0,
    sent_count INT DEFAULT 0,
    failed_count INT DEFAULT 0,
    sent_by TEXT DEFAULT 'admin',
    sent_at TIMESTAMP DEFAULT NOW()
);
