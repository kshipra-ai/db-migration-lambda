# =============================================================================
# run_data_reset.ps1
# =============================================================================
# Manually invoke a destructive SQL reset against the prod database via the
# existing db-migration-lambda's queryOnly mode.
#
# This script does NOT run automatically — it must be invoked by a human and
# requires typing a confirmation phrase before it sends anything to AWS.
#
# USAGE:
#   .\run_data_reset.ps1                            # dry-run, prints what would be sent
#   .\run_data_reset.ps1 -Execute                   # actually invoke the Lambda
#   .\run_data_reset.ps1 -Execute -SqlFile X.sql    # use an alternate SQL file
#
# REQUIREMENTS:
#   • AWS CLI configured with a profile that can invoke lambdaFn-db-migration-prod
#   • Default profile is "kshipra-dev" (same as the rest of the repo)
# =============================================================================

[CmdletBinding()]
param(
  [switch] $Execute,
  [string] $SqlFile      = "$PSScriptRoot\pre_launch_data_reset.sql",
  [string] $FunctionName = "lambdaFn-db-migration-prod",
  [string] $Profile      = "kshipra-dev",
  [string] $Region       = "ca-central-1"
)

$ErrorActionPreference = "Stop"

function Write-Section {
  param([string] $Title)
  Write-Host ""
  Write-Host ("=" * 70) -ForegroundColor DarkGray
  Write-Host $Title -ForegroundColor Cyan
  Write-Host ("=" * 70) -ForegroundColor DarkGray
}

# -----------------------------------------------------------------------------
# 1. Pre-flight checks
# -----------------------------------------------------------------------------
Write-Section "Pre-flight checks"

if (-not (Test-Path $SqlFile)) {
  Write-Error "SQL file not found: $SqlFile"
  exit 1
}

$sqlContent = Get-Content $SqlFile -Raw
if ([string]::IsNullOrWhiteSpace($sqlContent)) {
  Write-Error "SQL file is empty: $SqlFile"
  exit 1
}

Write-Host "  SQL file        : $SqlFile"
Write-Host "  SQL bytes       : $($sqlContent.Length)"
Write-Host "  Target Lambda   : $FunctionName"
Write-Host "  AWS profile     : $Profile"
Write-Host "  AWS region      : $Region"

try {
  $caller = aws sts get-caller-identity --profile $Profile --region $Region --output json 2>$null | ConvertFrom-Json
  if ($caller) {
    Write-Host "  AWS account     : $($caller.Account)"
    Write-Host "  AWS arn         : $($caller.Arn)"
  }
} catch {
  Write-Warning "Could not verify AWS credentials (continuing — Lambda invoke will fail if creds are bad)."
}

# -----------------------------------------------------------------------------
# 2. Show preview
# -----------------------------------------------------------------------------
Write-Section "SQL preview (first 40 lines)"
$sqlContent.Split("`n") | Select-Object -First 40 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
Write-Host "  ... ($($sqlContent.Split("`n").Count) total lines)"

# -----------------------------------------------------------------------------
# 3. Dry-run early exit
# -----------------------------------------------------------------------------
if (-not $Execute) {
  Write-Section "DRY RUN — no Lambda invoke"
  Write-Host "  Re-run with -Execute to actually run this against prod." -ForegroundColor Yellow
  exit 0
}

# -----------------------------------------------------------------------------
# 4. Confirmation prompt
# -----------------------------------------------------------------------------
Write-Section "DESTRUCTIVE ACTION CONFIRMATION"
Write-Host "  You are about to wipe USER DATA from kshipra_production." -ForegroundColor Red
Write-Host "  • Configuration tables and migration history are preserved." -ForegroundColor Yellow
Write-Host "  • Have you taken an RDS snapshot in the last hour? (recommended)" -ForegroundColor Yellow
Write-Host "  • Have you cleared / planned to clear the Cognito user pool? (recommended)" -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "Type RESET-PROD-DATA to continue (anything else aborts)"
if ($confirm -ne "RESET-PROD-DATA") {
  Write-Host "Aborted." -ForegroundColor Yellow
  exit 1
}

# -----------------------------------------------------------------------------
# 5. Build payload and invoke
# -----------------------------------------------------------------------------
Write-Section "Invoking Lambda"

$payloadObj  = @{ queryOnly = $true; query = $sqlContent }
$payloadJson = $payloadObj | ConvertTo-Json -Compress -Depth 5

$tmpPayload = New-TemporaryFile
$tmpResp    = New-TemporaryFile
try {
  Set-Content -Path $tmpPayload -Value $payloadJson -Encoding UTF8 -NoNewline

  Write-Host "  Payload bytes   : $($payloadJson.Length)"
  Write-Host "  Function name   : $FunctionName"
  Write-Host "  Invoking..." -ForegroundColor Cyan

  $invokeResult = aws lambda invoke `
    --function-name $FunctionName `
    --payload "fileb://$tmpPayload" `
    --cli-binary-format raw-in-base64-out `
    --profile $Profile `
    --region  $Region `
    --output  json `
    "$tmpResp" 2>&1

  if ($LASTEXITCODE -ne 0) {
    Write-Error "Lambda invoke failed: $invokeResult"
    exit 1
  }

  Write-Section "Lambda invoke metadata"
  Write-Host $invokeResult

  Write-Section "Lambda response body"
  $responseRaw = Get-Content $tmpResp -Raw
  Write-Host $responseRaw

  try {
    $response = $responseRaw | ConvertFrom-Json
    if ($response.statusCode -eq 200) {
      Write-Host ""
      Write-Host "SUCCESS — review CloudWatch /aws/lambda/$FunctionName for full notice output." -ForegroundColor Green
    } else {
      Write-Host ""
      Write-Host "FAILED with statusCode $($response.statusCode)." -ForegroundColor Red
      exit 1
    }
  } catch {
    Write-Warning "Could not parse response JSON; raw body shown above."
  }
} finally {
  Remove-Item $tmpPayload -ErrorAction SilentlyContinue
  Remove-Item $tmpResp    -ErrorAction SilentlyContinue
}

Write-Section "Next steps"
Write-Host "  1. Tail logs: aws logs tail /aws/lambda/$FunctionName --profile $Profile --region $Region --since 5m"
Write-Host "  2. Spot-check counts:"
Write-Host "       SELECT relname, n_live_tup FROM pg_stat_user_tables"
Write-Host "       WHERE schemaname='kshipra_core' ORDER BY n_live_tup DESC;"
Write-Host "  3. Sync Cognito user pool if not already done."
Write-Host "  4. Run a smoke test signup + scan + redemption."
