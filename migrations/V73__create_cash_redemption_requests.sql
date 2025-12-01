-- V73: Create cash redemption requests table
CREATE TABLE IF NOT EXISTS kshipra_core.cash_redemption_requests (
    request_id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount >= 5.00),
    status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed')),
    payment_method VARCHAR(100),
    payment_details JSONB,
    admin_notes TEXT,
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    processed_by VARCHAR(255),
    CONSTRAINT fk_user
        FOREIGN KEY(user_id) 
        REFERENCES kshipra_core.user_profile(user_id)
        ON DELETE CASCADE
);

CREATE INDEX idx_cash_redemption_user_id ON kshipra_core.cash_redemption_requests(user_id);
CREATE INDEX idx_cash_redemption_status ON kshipra_core.cash_redemption_requests(status);
CREATE INDEX idx_cash_redemption_requested_at ON kshipra_core.cash_redemption_requests(requested_at DESC);

COMMENT ON TABLE kshipra_core.cash_redemption_requests IS 'Stores cash redemption requests from users';
COMMENT ON COLUMN kshipra_core.cash_redemption_requests.amount IS 'Amount to redeem in USD (minimum $5)';
COMMENT ON COLUMN kshipra_core.cash_redemption_requests.status IS 'Status: pending, approved, rejected, completed';
COMMENT ON COLUMN kshipra_core.cash_redemption_requests.payment_details IS 'Payment details provided by user (UPI, bank account, etc.)';
