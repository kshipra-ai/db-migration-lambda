-- V177: Add CHECK constraint to enforce that the four-way earnings split
-- (user_rewards_points + cashback_cents + commission_points + business_share_points)
-- always equals total_reward_points on new rows.
-- NOT VALID: existing rows are not re-validated; only new inserts/updates are checked.

ALTER TABLE kshipra_core.kshipra_earnings
    DROP CONSTRAINT IF EXISTS chk_kshipra_earnings_distribution_balances;

ALTER TABLE kshipra_core.kshipra_earnings
    ADD CONSTRAINT chk_kshipra_earnings_distribution_balances
        CHECK (
            COALESCE(user_rewards_points, 0)
            + COALESCE(cashback_cents, 0)
            + COALESCE(commission_points, 0)
            + COALESCE(business_share_points, 0)
            = COALESCE(total_reward_points, 0)
        ) NOT VALID;

COMMENT ON CONSTRAINT chk_kshipra_earnings_distribution_balances
    ON kshipra_core.kshipra_earnings IS
'New earning rows must reconcile user points, user cash, Kshipra commission, and business share to the gross reward amount.';
