# Multi-cloud minimal serverless (LAMBDA)

One Python app (`src/`), three cloud stacks (`infra/{aws,gcp,az}/`), builds land in `dist/`.

## Quick start

```bash
uv sync                   # dev deps (pytest) — or: bin/setup.sh
cp .env.example .env      # optional — CLI creds auto-detected
source bin/load-env.sh
bash bin/apply.sh         # build → terraform apply per cloud
bash bin/wire-peers.sh    # cross-cloud peer URLs
```

## Layout

```
src/                    # business logic (cloud-agnostic)
infra/
  aws/python/           # Lambda handler, S3 blob, HTTP adapter
  aws/terraform/
  gcp/python/           # Cloud Function, GCS blob
  gcp/terraform/
  az/python/            # Azure Function, blob, host.json
  az/terraform/
dist/                   # build output (gitignored)
bin/                    # build, apply, test, env scripts
pyproject.toml          # uv project (dev deps)
AGENTS.md               # agent / maintainer notes
```

## Dev & test (uv)

```bash
uv sync
uv run pytest             # or: bin/test.sh
```

## Build & deploy

```bash
bash bin/build.sh all     # or: aws | gcp | az
```

Terraform reads `dist/<cloud>/function.zip` — run `build.sh` before `terraform apply`.

```bash
cd infra/aws/terraform && terraform init && terraform apply
cd infra/gcp/terraform && terraform apply -var="gcp_project_id=..."
cd infra/az/terraform  && terraform apply
```

Live URLs: `WORK.md`. Agent notes: `AGENTS.md`.
