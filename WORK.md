# Deployments

Last updated: 2026-06-22 (per-cloud infra layout)

| Cloud | Terraform | Build artifact |
|-------|-----------|----------------|
| AWS | `infra/aws/terraform` | `dist/aws/function.zip` |
| GCP | `infra/gcp/terraform` | `dist/gcp/function.zip` |
| Azure | `infra/az/terraform` | `dist/az/function.zip` |

## Commands

```bash
bash bin/build.sh all
bash bin/apply.sh
bash bin/wire-peers.sh
```

## Smoke test

```bash
curl -s "$(terraform -chdir=infra/aws/terraform output -raw base_url)/health"
curl -s "$(terraform -chdir=infra/gcp/terraform output -raw base_url)/health"
curl -s "$(terraform -chdir=infra/az/terraform output -raw base_url)/health"
```

Note: after layout change, run `terraform init` in each `infra/*/terraform` dir. Existing unified `terraform/` state was removed — import or redeploy per cloud.
