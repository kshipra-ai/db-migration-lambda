-- V169: Set default business share to 10% for QR host locations.
-- Reduces Kshipra commission from 25% → 15% to keep the total at 100%.
-- New split: 50% user rewards, 25% cashback, 15% Kshipra commission, 10% business share.

UPDATE kshipra_core.reward_distribution_config
SET
    kshipra_commission_percentage = 15.00,
    business_share_percentage     = 10.00,
    notes = 'Default split: 50% user rewards, 25% cashback, 15% Kshipra commission, 10% QR host business share'
WHERE is_active = TRUE;
