$payload = @{
    queryOnly = $true
    query = "UPDATE kshipra_core.system_configurations SET config_value = jsonb_set(jsonb_set(config_value, '{referrer_reward,type}', '`"cashback`"'), '{referee_reward,type}', '`"cashback`"') WHERE config_key = 'referral_system'"
} | ConvertTo-Json -Compress

Write-Host "Payload: $payload"

# Write payload to file
$payload | Out-File -FilePath "v97-fix-payload.json" -Encoding ASCII -NoNewline

# Invoke Lambda
aws lambda invoke --function-name lambdaFn-db-migration-prod --payload file://v97-fix-payload.json v97-fix-result.json

# Show result
Get-Content v97-fix-result.json | ConvertFrom-Json | ConvertTo-Json
