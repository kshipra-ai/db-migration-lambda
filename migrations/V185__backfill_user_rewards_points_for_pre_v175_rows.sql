-- V185: Backfill user_rewards_points for pre-V175 kshipra_earnings rows.
-- V175 added user_rewards_points and cashback_cents with DEFAULT 0, so rows
-- inserted before V175 have 0 for both even though the user did receive the
-- difference (total_reward_points - commission_points - business_share_points).
-- In the pre-cashback era the entire user portion was points, so we assign it
-- all to user_rewards_points and leave cashback_cents = 0.
UPDATE kshipra_core.kshipra_earnings
SET user_rewards_points = GREATEST(
        0,
        COALESCE(total_reward_points, 0)
            - COALESCE(commission_points, 0)
            - COALESCE(business_share_points, 0)
    )
WHERE user_rewards_points = 0
  AND cashback_cents = 0
  AND COALESCE(total_reward_points, 0)
      > COALESCE(commission_points, 0) + COALESCE(business_share_points, 0);
