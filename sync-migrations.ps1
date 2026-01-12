#!/usr/bin/env pwsh
# Sync migrations from kshipra-db to db-migration-lambda

$ErrorActionPreference = "Stop"

$kshipraDbPath = "$PSScriptRoot\..\kshipra-db\flyway\sql"
$migrationsPath = "$PSScriptRoot\migrations"

if (-not (Test-Path $kshipraDbPath)) {
    Write-Error "kshipra-db not found at $kshipraDbPath"
    exit 1
}

Write-Host "🔄 Syncing migrations from kshipra-db..." -ForegroundColor Cyan

# Remove old V*.sql files
Get-ChildItem -Path $migrationsPath -Filter "V*.sql" | Remove-Item

# Copy new ones
Copy-Item -Path "$kshipraDbPath\V*.sql" -Destination $migrationsPath

$count = (Get-ChildItem -Path $migrationsPath -Filter "V*.sql").Count
Write-Host "✅ Synced $count migration files" -ForegroundColor Green

# Show latest 5
Write-Host "`nLatest migrations:" -ForegroundColor Yellow
Get-ChildItem -Path $migrationsPath -Filter "V*.sql" | Sort-Object Name | Select-Object -Last 5 | ForEach-Object { Write-Host "  $_" }
