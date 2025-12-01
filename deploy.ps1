param([string]$Environment = "production")
$ErrorActionPreference = "Stop"

Write-Host "Deploying DB Migration Lambda to $Environment..." -ForegroundColor Cyan

if (-not (Test-Path "db-migration-lambda.zip")) {
    Write-Host "ERROR: Build package not found. Run .\build.ps1 first" -ForegroundColor Red
    exit 1
}

$env:AWS_PROFILE = "kshipra-dev"
# Map environment names to match Terraform naming (production -> prod)
$envSuffix = if ($Environment -eq "production") { "prod" } else { $Environment }
$lambdaName = "lambdaFn-db-migration-$envSuffix"

Write-Host "Checking if lambda exists..."
$exists = $false
try {
    aws lambda get-function --function-name $lambdaName 2>&1 | Out-Null
    $exists = $LASTEXITCODE -eq 0
} catch {}

if ($exists) {
    Write-Host "Updating existing lambda code..." -ForegroundColor Yellow
    aws lambda update-function-code --function-name $lambdaName --zip-file fileb://db-migration-lambda.zip
    Write-Host "Lambda updated!" -ForegroundColor Green
} else {
    Write-Host "ERROR: Lambda does not exist. Creating via AWS CLI requires DB password." -ForegroundColor Red
    Write-Host "Option 1: Use AWS Console to create the lambda manually" -ForegroundColor Yellow
    Write-Host "Option 2: Run: aws lambda create-function with all parameters" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "To invoke: aws lambda invoke --function-name $lambdaName output.json --profile kshipra-dev" -ForegroundColor Cyan
