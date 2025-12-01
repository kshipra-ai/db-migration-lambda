# DB Migration Lambda - PROD

Automated database migration system for kshipra_production using AWS Lambda.

## Architecture

- **Lambda Function**: `lambdaFn-db-migration-prod`
- **Runtime**: Node.js 20.x
- **VPC**: Runs in private subnets to access RDS
- **Database**: PostgreSQL (kshipra_production)
- **Migration Tracking**: Flyway-compatible schema history

## Features

- ✅ Automatic migration on push to `main` branch (via GitHub Actions)
- ✅ Manual trigger via AWS CLI or GitHub Actions
- ✅ Transactional execution with rollback on errors
- ✅ Graceful handling of existing schema objects
- ✅ MD5 checksum validation
- ✅ CloudWatch logging

## GitHub Actions Setup

### Required Secrets

Add these secrets to your GitHub repository (`Settings → Secrets → Actions`):

```
AWS_ACCESS_KEY_ID       - AWS access key with Lambda invoke permissions
AWS_SECRET_ACCESS_KEY   - AWS secret key
```

### Automatic Deployment

Migrations run automatically when:
- Code is pushed to `main` branch
- Changes detected in `index.js`, `package.json`, or `migrations/`

### Manual Trigger

1. Go to `Actions` tab in GitHub
2. Select "Deploy PROD Migrations" workflow
3. Click "Run workflow"
4. Select `main` branch
5. Click "Run workflow" button

## Local Development

### Prerequisites

- Node.js 20.x
- AWS CLI configured with `kshipra-dev` profile
- Access to `kshipra-db` repository (for migrations)

### Build Lambda Package

```powershell
.\build.ps1
```

This will:
1. Install Node.js dependencies
2. Copy latest migrations from `../kshipra-db/flyway/sql/`
3. Create `db-migration-lambda.zip`

### Deploy to Lambda

```powershell
.\deploy.ps1 -Environment production
```

### Run Migrations Manually

```powershell
aws lambda invoke `
  --function-name lambdaFn-db-migration-prod `
  --profile kshipra-dev `
  output.json

Get-Content output.json | ConvertFrom-Json
```

## Migration Files

Migrations are stored in `../kshipra-db/flyway/sql/` and follow Flyway naming convention:

```
V1__initial_schema.sql
V2__add_users.sql
V3__add_campaigns.sql
...
```

**Rules:**
- Prefix: `V` + version number + `__` + description + `.sql`
- Versions must be sequential
- Once applied, migrations should NOT be modified
- New changes require new version files

## Infrastructure

Created via Terraform in `aws-terraform/infra/db_migration_lambda.tf`:

```terraform
resource "aws_lambda_function" "db_migration" {
  function_name = "lambdaFn-db-migration-prod"
  runtime       = "nodejs20.x"
  memory_size   = 1024
  timeout       = 900  # 15 minutes
  
  vpc_config {
    subnet_ids         = [subnet-07c7eb3115041df14, ...]
    security_group_ids = [sg-05eb33bcd70c8134a]
  }
  
  environment {
    variables = {
      DB_HOST     = "lambdafn-production.cl466woecfi5.ca-central-1.rds.amazonaws.com"
      DB_NAME     = "kshipra_production"
      DB_USER     = "kshipra_admin"
      DB_PASSWORD = "***"
      DB_PORT     = "5432"
      ENVIRONMENT = "prod"
    }
  }
}
```

## Monitoring

### CloudWatch Logs

```powershell
aws logs tail /aws/lambda/lambdaFn-db-migration-prod `
  --profile kshipra-dev `
  --follow
```

### Check Migration History

Query the database:

```sql
SELECT version, description, installed_on, success 
FROM kshipra_core.flyway_schema_history 
ORDER BY installed_rank;
```

## Troubleshooting

### Migration Fails with "already exists"

The Lambda gracefully handles objects that already exist and marks them as applied. Check CloudWatch logs for details.

### Connection Timeout

Ensure:
- Lambda security group (`sg-05eb33bcd70c8134a`) is allowed in RDS security group
- Lambda is in correct VPC subnets
- RDS endpoint is accessible from Lambda

### Password Authentication Failed

RDS password is stored in `aws-terraform/infra/prod.tfvars`. If changed:

```powershell
aws rds modify-db-instance `
  --db-instance-identifier lambdafn-production `
  --master-user-password 'NEW_PASSWORD' `
  --apply-immediately `
  --profile kshipra-dev
```

Then update Terraform and redeploy.

## Development Workflow

1. **Add new migration** to `kshipra-db/flyway/sql/`
   ```sql
   -- V97__add_feature_x.sql
   CREATE TABLE kshipra_core.feature_x (...);
   ```

2. **Push to main branch** (GitHub Actions will handle the rest)
   ```bash
   git add kshipra-db/flyway/sql/V97__add_feature_x.sql
   git commit -m "Add feature X migration"
   git push origin main
   ```

3. **Monitor deployment** in GitHub Actions tab

4. **Verify in database**
   ```sql
   SELECT * FROM kshipra_core.flyway_schema_history 
   WHERE version = '97';
   ```

## Security

- ✅ Database credentials stored in environment variables (managed by Terraform)
- ✅ Lambda runs in private VPC (no internet access)
- ✅ IAM role follows least-privilege principle
- ✅ AWS credentials stored as GitHub Secrets (encrypted)

## Support

For issues or questions:
- Check CloudWatch logs: `/aws/lambda/lambdaFn-db-migration-prod`
- Review migration files in `kshipra-db` repository
- Contact DevOps team
