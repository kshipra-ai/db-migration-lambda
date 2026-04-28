# db-migration-lambda / ops

**Operational runbook scripts. NOT migrations. NOT auto-run.**

This folder contains destructive / operational SQL scripts that are invoked
**manually** by an operator with prod access — they do **not** participate in
the Flyway migration pipeline.

## Why this folder exists

Flyway versioned migrations (`migrations/V*.sql`) run on every fresh DB,
every snapshot restore, and every new environment. That contract is correct
for schema changes — but it is **wrong** for one-off destructive ops like
"wipe all user data before public launch".

So we keep break-glass SQL here, outside the migration loop:

| Folder | Auto-runs? | Tracked by Flyway? | Purpose |
|--------|-----------|--------------------|---------|
| `migrations/` | ✅ Yes (on Lambda invoke / GH Action) | ✅ Yes | Schema + idempotent data migrations |
| `ops/` (**this folder**) | ❌ No | ❌ No | Manual destructive / operational SQL |

## Files

| File | Purpose |
|------|---------|
| `pre_launch_data_reset.sql` | Empties all user-generated data tables in `kshipra_core`. Preserves `flyway_schema_history`, app config, and reference catalogs. Discovers tables dynamically. |
| `run_data_reset.ps1` | PowerShell wrapper. Confirms before sending. Invokes `lambdaFn-db-migration-prod` in `queryOnly` mode with the SQL as the `query` field. |

## How it executes

The wrapper does **not** open a direct DB connection. Instead it invokes the
existing `lambdaFn-db-migration-prod` Lambda using its `queryOnly` mode
(see `index.js`):

```javascript
if (event && event.queryOnly) {
  if (event.query) {
    const result = await client.query(event.query);
    return { statusCode: 200, body: JSON.stringify({ rows: result.rows }) };
  }
  // ... default returns flyway_schema_history
}
```

This means:

- ✅ The reset uses the **same** VPC, security groups, and DB credentials as
  every other migration.
- ✅ It runs from inside AWS (no need to SSH / bastion / open RDS to your IP).
- ✅ All output is captured in **CloudWatch** under
  `/aws/lambda/lambdaFn-db-migration-prod`.
- ❌ It **never** writes to `flyway_schema_history` and is **invisible** to the
  migration system.

## Safety mechanisms

- **Dry-run by default** — `run_data_reset.ps1` without `-Execute` only previews.
- **Confirmation prompt** — must type `RESET-PROD-DATA` exactly before invoking.
- **Transaction-wrapped** — the SQL itself runs inside `DO $$...END $$` and any
  error rolls back the entire wipe.
- **Allow-list, not deny-list** — the SQL has an explicit `preserve_tables`
  array. Anything not in that list **AND** present in `kshipra_core` will be
  truncated. Edit the array if you want to preserve more.
- **No network exposure** — wrapper invokes a Lambda; it does not open
  a direct DB connection from your laptop.

## What gets cleared / preserved

Cleared (everything in `kshipra_core` except the preserve list):
- All `user_*` tables
- All `campaign*` tables
- All `qr_*` tables
- All redemption / earnings / transaction tables
- All survey / referral / tree-planting tables
- App feedback, announcements, email blast history, partner data, etc.

Preserved by default:
- `flyway_schema_history` — **never delete**, breaks migrations
- `system_configurations`
- `payment_config`
- `reward_distribution_config`
- `survey_revenue_config`
- `survey_providers`
- `pitch_kb_changes`, `pitch_ceo_context`, `pitch_custom_questions`
  (admin tooling — review and remove from preserve list if you want them cleared)

To change what gets preserved, edit the `preserve_tables` array near the top
of `pre_launch_data_reset.sql`.

## Pre-flight checklist (do these BEFORE running)

1. **Take an RDS snapshot.**
   ```powershell
   aws rds create-db-snapshot `
     --db-instance-identifier lambdafn-production `
     --db-snapshot-identifier "pre-launch-cleanup-$(Get-Date -Format 'yyyyMMdd-HHmm')" `
     --profile kshipra-dev --region ca-central-1
   ```
2. **Confirm target DB.** The Lambda env hardcodes `kshipra_production`. Verify
   in AWS Console → Lambda → `lambdaFn-db-migration-prod` → Configuration → Env.
3. **Plan Cognito sync.** Wiping `user_profile` while leaving the Cognito user
   pool populated produces zombie logins. Either:
   - Empty the pool: AWS Console → Cognito → User Pools →
     `ca-central-1_gXS6BHebl` → Users → bulk delete
   - Accept that pre-launch test signups will get "user not found" on next
     login (and document this).
4. **Freeze deploys** for the duration of the window.
5. **Review the preserve list.** Open `pre_launch_data_reset.sql` and confirm
   the `preserve_tables` array matches your intent.

## Usage

### Dry-run (always start here)

```powershell
cd c:\kshipra-codebase\db-migration-lambda\ops
.\run_data_reset.ps1
```

Prints what would be sent. No AWS calls beyond `sts get-caller-identity`.

### Execute (irreversible)

```powershell
.\run_data_reset.ps1 -Execute
```

Will prompt for `RESET-PROD-DATA` confirmation before invoking the Lambda.

### Custom SQL file

```powershell
.\run_data_reset.ps1 -Execute -SqlFile .\some_other_op.sql
```

### Different account/region

```powershell
.\run_data_reset.ps1 -Execute -Profile my-prod-profile -Region us-east-1
```

## Verifying the result

After execution:

```powershell
# 1. Tail Lambda logs
aws logs tail /aws/lambda/lambdaFn-db-migration-prod `
  --profile kshipra-dev --region ca-central-1 --since 5m

# 2. Spot-check via the Lambda's queryOnly mode itself
$payload = '{"queryOnly":true,"query":"SELECT relname, n_live_tup FROM pg_stat_user_tables WHERE schemaname=''kshipra_core'' ORDER BY n_live_tup DESC LIMIT 30"}'
$payload | Out-File -Encoding utf8 -NoNewline tmp-payload.json

aws lambda invoke `
  --function-name lambdaFn-db-migration-prod `
  --payload fileb://tmp-payload.json `
  --cli-binary-format raw-in-base64-out `
  --profile kshipra-dev --region ca-central-1 `
  out.json

Get-Content out.json
Remove-Item tmp-payload.json, out.json
```

Live tuple counts on user data tables should be **0**; preserved config tables
should be **non-zero**.

## Re-running later (post-launch resets)

This whole pattern is reusable. To wipe again:

- **Same scope** (clear user data, preserve config) → re-run
  `run_data_reset.ps1 -Execute`. Nothing in this script is single-use.
- **Different scope** (e.g. clear specific tables only) → copy
  `pre_launch_data_reset.sql` to a new file in this folder, edit the
  `preserve_tables` array (or write a different SQL block entirely), and run
  `run_data_reset.ps1 -Execute -SqlFile your_new_file.sql`.

The `migrations/` folder is **never** touched by these resets.

## What this folder is NOT

- **Not** a migration. Don't add `V###__` files here.
- **Not** auto-deployed. GitHub Actions does not invoke anything in this folder.
- **Not** versioned data. The SQL is idempotent in spirit but the EFFECT is
  one-shot per run; `flyway_schema_history` does not track it.

## Audit trail

Every invocation is logged to:
- **CloudWatch**: `/aws/lambda/lambdaFn-db-migration-prod`
- **CloudTrail**: Lambda invoke event (with caller ARN)

If you need a stronger audit, write the operator's name and ticket number into
a comment at the top of the SQL file before running and commit it to git.
