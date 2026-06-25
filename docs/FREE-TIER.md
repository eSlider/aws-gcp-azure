# Running LAMBADA on free tier

LAMBADA can run at **$0/month** for light hobby traffic if you stay inside each cloud’s free allowances. This stack uses only serverless compute + object storage (no VMs, NAT gateways, or databases).

**Verify limits on official pages** — vendors change free programs. Links below were checked June 2026.

| Cloud | Official free-tier reference |
|-------|------------------------------|
| AWS | [AWS Free Tier](https://aws.amazon.com/free/), [Lambda pricing](https://aws.amazon.com/lambda/pricing/), [API Gateway pricing](https://aws.amazon.com/api-gateway/pricing/), [S3 pricing](https://aws.amazon.com/s3/pricing/) |
| GCP | [Free cloud features](https://cloud.google.com/free/docs/free-cloud-features), [Cloud Run pricing](https://cloud.google.com/run/pricing), [Cloud Storage pricing](https://cloud.google.com/storage/pricing) |
| Azure | [Free Azure services](https://azure.microsoft.com/en-us/pricing/free-services), [Functions pricing](https://azure.microsoft.com/en-us/pricing/details/functions/) |

## What LAMBADA deploys

| Cloud | Services in this repo | Terraform defaults |
|-------|----------------------|-------------------|
| AWS | Lambda 256 MB, HTTP API (API Gateway v2), S3 bucket, CloudWatch Logs (7-day retention) | `AWS_REGION=eu-central-1` |
| GCP | Cloud Functions Gen2 (Cloud Run), 2× GCS buckets, Cloud Build on deploy | `GCP_REGION=us-central1` |
| Azure | Linux Function App (Consumption `Y1`), Storage account (LRS), blob containers | `AZURE_LOCATION=westeurope` |

## Account setup (one-time)

### AWS

1. Create an account ([AWS Free Tier](https://aws.amazon.com/free/)).
2. New accounts (from July 2025) may choose a **6-month free plan** with up to **$200 credits**, or pay-as-you-go with always-free services.
3. Configure CLI: `aws login` or static keys in `.env`.
4. Optional: set a **billing budget alarm** in the AWS Billing console.

### GCP

1. Create a project and enable billing ([Google Cloud free program](https://cloud.google.com/free/docs/free-cloud-features)).
2. New customers get **$300 trial credit** (90 days) plus monthly free-tier caps on many products.
3. **Use a US region for storage free tier:** `us-central1`, `us-east1`, or `us-west1` (default in `.env.example` is `us-central1`).
4. `gcloud auth login` and `gcloud auth application-default login`.

### Azure

1. Create a [free Azure account](https://azure.microsoft.com/en-us/free/) ($200 credit for 30 days for new customers).
2. `az login` — set `AZURE_TENANT_ID` in `.env` if needed.
3. This repo uses **Linux Consumption** (`Y1`). Microsoft is retiring Linux Consumption in 2028; plan to migrate to Flex Consumption later ([hosting docs](https://learn.microsoft.com/en-us/azure/azure-functions/functions-scale)).

## Free-tier limits vs this stack

### AWS

| Service | Monthly free allowance (typical) | LAMBADA usage | Practical note |
|---------|----------------------------------|---------------|----------------|
| **Lambda** | 1M requests + 400K GB-s ([pricing](https://aws.amazon.com/lambda/pricing/)) | 256 MB, up to 30 s timeout | Always-free for AWS customers. At 256 MB × 200 ms ≈ 0.05 GB-s/call → compute caps around **~8M short calls**; **1M requests** is usually the tighter limit. |
| **API Gateway HTTP API** | 1M calls for **12 months** (new accounts) ([pricing](https://aws.amazon.com/api-gateway/pricing/)) | Every HTTP route | Not “always free” — after 12 months, ~$1/million calls. |
| **S3 Standard** | 5 GB storage, 20K GET, **2K PUT** ([S3 pricing](https://aws.amazon.com/s3/pricing/)) | One JSON PUT per webhook | **~2K ingested events/month** before PUT charges (~66/day). Storage of small JSON files stays under 5 GB for a long time. |
| **CloudWatch Logs** | ~5 GB ingestion (basic / account-dependent) | Lambda logs, 7-day retention | Low traffic is fine; noisy errors or debug logging can add cost. |
| **Data transfer out** | First 1 GB/month to internet (varies) | API responses, peer `notify` HTTP | Cross-cloud peer calls egress from each cloud. Keep payloads small. |

### GCP

| Service | Monthly free allowance (typical) | LAMBADA usage | Practical note |
|---------|----------------------------------|---------------|----------------|
| **Cloud Run** (Gen2 functions) | 2M requests, 360K GiB-s memory, 180K vCPU-s, 1 GB egress ([Cloud Run pricing](https://cloud.google.com/run/pricing)) | 256 MiB, scales 0–2 instances | Gen2 functions bill as Cloud Run. Fits hobby traffic easily. |
| **Cloud Storage** | 5 GB-months, 5K **Class A**, 50K Class B, 100 GB egress — **US regions only** ([free features](https://cloud.google.com/free/docs/free-cloud-features)) | `events` + `src` buckets; PUT per webhook | **~5K writes/month** (~166/day). Deploy uploads count as Class A too. |
| **Cloud Build** | 2,500 build-minutes (`e2-standard-2`) | Runs when Terraform deploys the function | Redeploying often burns minutes; `bin/build.sh` locally + apply is cheaper than repeated full rebuilds. |
| **Artifact Registry** | 500 MB | Container images from Gen2 builds | Usually fine for one small function. |
| **Cloud Logging** | 50 GiB/project | Function stdout | Generous for this app. |

### Azure

| Service | Monthly free allowance (typical) | LAMBADA usage | Practical note |
|---------|----------------------------------|---------------|----------------|
| **Functions Consumption** | 1M executions + 400K GB-s per subscription ([pricing](https://azure.microsoft.com/en-us/pricing/details/functions/)) | Linux Consumption `Y1` | Compute grant is **not** tied to storage. |
| **Blob Storage (LRS Hot)** | 5 GB + 20K reads + **10K writes** for **12 months** (new accounts) ([free services](https://azure.microsoft.com/en-us/pricing/free-services)) | Events container + deploy blob | **~10K writes/month** during first year (~333/day). After 12 months, storage is pay-as-you-go. |
| **Storage account** | Required by Functions runtime | Billed separately from Functions grant | Even at $0 compute, a few cents/month for storage is possible after free period. |

## Cross-cloud peer traffic

`bin/wire-peers.sh` configures each cloud to `POST` to the others on every ingested webhook.

Per webhook stored on **one** cloud:

- 1 HTTP request to that cloud’s API
- 1 blob write
- 1 Lambda/Function invocation on that cloud
- **2 outbound peer notifications** (to the other clouds)
- **2 additional invocations** on peer clouds ( `/internal/event` )

Rough monthly totals for **N** webhooks to a single entry cloud (all three clouds deployed):

| Resource (all clouds combined) | Order of magnitude |
|-------------------------------|-------------------|
| HTTP + function invocations | ~3N (entry + 2 peers) |
| Blob writes | N (only the entry cloud stores the event) |
| Egress | ~2N small JSON POSTs |

Example: **1,000 webhooks/month** → ~3K invocations and ~1K S3/GCS/Blob writes — well within compute free tiers, but check **S3 PUT (2K)** and **GCS Class A (5K)** caps.

## Recommended free-tier workflow

```bash
# 1. Prefer free-tier-friendly regions in .env
#    GCP_REGION=us-central1   (required for GCS free tier)
#    AWS_REGION=us-east-1     (optional; eu-central-1 works but S3 free tier is global per account)
#    AZURE_LOCATION=westeurope

cp .env.example .env
bash bin/discover-env.sh          # confirm logins

# 2. Deploy one cloud first (saves credits while learning)
source bin/load-env.sh
bash bin/build.sh aws
cd infra/aws/terraform && terraform init && terraform apply \
  -var="resource_prefix=${RESOURCE_PREFIX}" -var="aws_region=${AWS_REGION}"

# 3. Smoke test
curl -s "$(terraform output -raw base_url)/health"

# 4. Add GCP + Azure when ready, then wire peers
bash bin/apply.sh
bash bin/wire-peers.sh

# 5. Tear down when idle (avoids stray storage charges)
bash bin/destroy.sh
```

### Stay at $0 — habits

1. **Set billing alerts** on all three clouds before `apply.sh`.
2. **Keep webhook volume low** — storage *write* free tiers are the first limits you hit, not Lambda/Cloud Run.
3. **Use `us-central1`** for GCP (already the default in `.env.example`).
4. **Avoid public load tests** on `/webhook/*` — each call writes storage and fans out to peers.
5. **Use `/query` sparingly on AWS** — DuckDB scans S3 (GET requests + egress).
6. **`terraform destroy`** when not experimenting — S3/GCS/Blob storage pennies add up over months.
7. **Do not commit** `.env`, `terraform.tfvars`, or `peers.auto.tfvars.json`.

## When you will pay

| Trigger | What bills |
|---------|------------|
| > ~2K AWS webhooks/month | S3 PUT overage |
| > ~5K GCP writes/month | GCS Class A overage |
| AWS account > 12 months old | HTTP API calls (no longer in 12-month free tier) |
| Azure account > 12 months old | Blob storage/ops (no longer in 12-month free tier) |
| Heavy `/query` usage | S3 GET + data transfer |
| Repeated `terraform apply` on GCP | Cloud Build minutes |
| Leaving stacks running with large event JSON | Storage GB-months |

## Is “all three clouds” realistic on free tier?

**Yes, for demos and light personal use** — three `/health` endpoints, occasional webhooks, and peer sync fit comfortably in **compute** free tiers.

**The bottleneck is object-storage write quotas**, especially AWS S3 (2K PUT/month). For a multi-cloud demo without heavy ingestion:

- Deploy all three and wire peers.
- Test with tens of webhooks per day, not thousands.
- Use `/health` and `/peers` freely.

For production or high-volume ingestion, budget a few dollars/month or single-cloud deploy only.
