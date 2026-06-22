# Multi-cloud minimal serverless health check

Deploy a tiny Python HTTP function returning `{"status": "ok"}` on AWS, GCP, and Azure using separate Terraform roots. Optimized for near-zero cost at low traffic.

## Architecture

| Cloud | Stack | Free-tier anchor |
|-------|-------|------------------|
| AWS | HTTP API (v2) + Lambda | Lambda: 1M requests/month |
| GCP | Cloud Run functions (gen2) | 2M requests/month (billing account required) |
| ~~Azure~~ | *skipped* | *no subscription yet* |

Each cloud has its own Terraform state under `terraform/<cloud>/`.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5
- Cloud accounts and credentials (see below)
- `curl` and optionally `jq` for smoke tests

## Quick start

1. Copy credentials template:

   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

2. Load environment (auto-detects from AWS/gcloud/az CLI when `.env` values are empty):

   ```bash
   source scripts/load-env.sh
   ```

   The script will:
   - **AWS:** export temporary session creds via `aws configure export-credentials` (for CLI login/SSO)
   - **GCP:** pick active `gcloud` project (or first in list); needs `gcloud auth application-default login` for Terraform
   - **Azure:** read subscription/tenant from `az account show` after `az login`

3. Deploy (Azure skipped — see below):

   ```bash
   # AWS
   cd terraform/aws
   terraform init && terraform apply

   # GCP (apply only after billing + ADC)
   cd ../gcp
   terraform init && terraform plan   # apply after billing
   ```

4. Smoke test:

   ```bash
   curl -s "$(terraform -chdir=terraform/aws output -raw api_invoke_url)"
   curl -s "$(terraform -chdir=terraform/gcp output -raw function_url)"
   ```

   Expected response: `{"status":"ok"}`

## Credentials setup

### `.env` variables

| Variable | Used by | Description |
|----------|---------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS | IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS | IAM secret key |
| `AWS_REGION` | AWS | Default: `us-east-1` |
| `GCP_PROJECT_ID` | GCP | GCP project ID |
| `GCP_REGION` | GCP | Default: `us-central1` |
| `GOOGLE_APPLICATION_CREDENTIALS` | GCP | Path to service account JSON |
| `ARM_SUBSCRIPTION_ID` | Azure | Subscription ID |
| `ARM_TENANT_ID` | Azure | Azure AD tenant ID |
| `ARM_CLIENT_ID` | Azure | Service principal app ID |
| `ARM_CLIENT_SECRET` | Azure | Service principal secret |
| `AZURE_LOCATION` | Azure | Default: `westeurope` |
| `RESOURCE_PREFIX` | All | Resource name prefix |

Never commit `.env` or credential files.

### AWS

Create an IAM user or role with permissions for:

- Lambda (create/update functions)
- API Gateway v2
- IAM (create execution role)
- CloudWatch Logs

Export keys via `.env` or use **AWS CLI login** — leave `AWS_ACCESS_KEY_ID` empty and `load-env.sh` will export a session automatically.

Detected account example: `aws sts get-caller-identity`

### Azure (skipped)

Azure deployment is **disabled for now** — `eslider@gmail.com` has no subscription in tenant `4be6dc4c-5da8-45ff-8451-a2fe079350c9`. The `terraform/azure/` stack remains in the repo for later.

When ready: create a [free Azure account](https://azure.microsoft.com/free/), then `az login --tenant 4be6dc4c-5da8-45ff-8451-a2fe079350c9` and deploy from `terraform/azure/`.

### GCP prerequisites (billing required)

GCP Cloud Functions need a **billing account** linked to the project, even if usage stays within the free tier.

1. Create or select a project at [console.cloud.google.com](https://console.cloud.google.com).
2. Link billing: Billing → Link a billing account.
3. Create a service account with roles:
   - `roles/cloudfunctions.admin`
   - `roles/storage.admin`
   - `roles/serviceusage.serviceUsageAdmin`
   - `roles/run.admin`
   - `roles/iam.serviceAccountUser`
4. Download JSON key → `credentials/gcp-sa.json`
5. Set `GCP_PROJECT_ID` and `GOOGLE_APPLICATION_CREDENTIALS` in `.env`
6. Set `gcp_project_id` in `terraform/gcp/terraform.tfvars`
7. Run `terraform apply` in `terraform/gcp/`

Until billing is enabled, use `terraform init`, `terraform validate`, and `terraform plan` only.

## Project layout

```
functions/
  aws/handler.py          # Lambda handler
  gcp/main.py             # Cloud Run function entry point
  azure/function_app.py   # Azure Functions v2 model
terraform/
  aws/                    # API Gateway + Lambda
  gcp/                    # Cloud Functions gen2
  azure/                  # Linux Consumption Function App
scripts/load-env.sh       # Export .env for providers
```

## Cost notes

- **AWS:** Lambda free tier covers 1M invocations/month. HTTP API adds ~$1 per 1M requests beyond negligible test traffic.
- **GCP:** 2M requests/month free in Tier-1 regions (e.g. `us-central1`). Billing account required.
- **Azure:** Consumption plan grants 1M executions/month. No Always Ready instances are configured.

## Cleanup

```bash
cd terraform/aws && terraform destroy
cd terraform/gcp && terraform destroy
# terraform/azure — skipped
```

## Security

Endpoints are **public** (`/health`, no auth) for simplicity. Restrict IAM/API access in production. Rotate credentials if exposed.
