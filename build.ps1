# Build script for DB migration lambda
$ErrorActionPreference = "Stop"

Write-Host "Building DB Migration Lambda..." -ForegroundColor Cyan

if (Test-Path "db-migration-lambda.zip") {
    Remove-Item "db-migration-lambda.zip" -Force
}

if (Test-Path "node_modules") {
    Remove-Item "node_modules" -Recurse -Force
}

Write-Host "Installing dependencies..."
npm install --omit=dev

New-Item -ItemType Directory -Force -Path "migrations" | Out-Null

Write-Host "Copying migrations from kshipra-db..."
if (Test-Path "..\kshipra-db\flyway\sql\V*.sql") {
    Copy-Item "..\kshipra-db\flyway\sql\V*.sql" -Destination "migrations\" -Force
    $migrationCount = (Get-ChildItem "migrations\V*.sql").Count
    Write-Host "Copied $migrationCount migration files" -ForegroundColor Green
} else {
    Write-Host "WARNING: kshipra-db migrations not found at ..\kshipra-db\flyway\sql\" -ForegroundColor Yellow
}

Write-Host "Creating package..."
Compress-Archive -Path "index.js", "package.json", "package-lock.json", "node_modules", "migrations" -DestinationPath "db-migration-lambda.zip" -Force

$zipSize = (Get-Item "db-migration-lambda.zip").Length / 1KB
Write-Host "Build complete! Package size: $([math]::Round($zipSize, 2)) KB" -ForegroundColor Green

