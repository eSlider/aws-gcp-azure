# AGENTS.md — aws-gcp-azure

Living notes for agents working on this repo. **Read this after `README.md`.**

## Project in one line

Multi-cloud serverless HTTP app (LAMBDA): shared BL in `src/`, per-cloud deploy code in `infra/{aws,gcp,az}/`, zips in `dist/`, orchestration in `bin/`.

## Operational order

1. `README.md` — layout and commands
2. This file — pitfalls and conventions
3. `WORK.md` — live URLs / deploy status
4. `bin/load-env.sh` — credentials before terraform

## Tooling (use uv by default)

```bash
uv sync              # or: bin/setup.sh — dev venv + pytest
uv run pytest        # or: bin/test.sh
bash bin/build.sh all
bash bin/apply.sh
bash bin/wire-peers.sh
```

- **Do not** use `pip install` / manual `.venv` for dev — use `uv sync`.
- **Do not** commit `.venv/`; **do** commit `uv.lock`.
- Runtime/cloud deps stay in `infra/<cloud>/python/requirements.txt` (not root `pyproject.toml`).
- Azure zip vendoring: `bin/build.sh az` runs `uv pip install --target … --python-platform x86_64-manylinux_2_28 --python-version 3.12 --only-binary :all:` (Azure Functions = Linux py3.12; do not install with host Python 3.14 wheels).

## Layout rules

| Path | Role |
|------|------|
| `src/` | Business logic only — no boto3 / google-cloud / azure SDK imports |
| `infra/<cloud>/python/` | HTTP adapter, blob facade, storage/query, runtime entry |
| `infra/<cloud>/terraform/` | Standalone terraform root + own state |
| `dist/<cloud>/function.zip` | Build output (gitignored); terraform reads this |

**Dependency direction:** `src/` → cloud modules at **package** time only via lazy imports (`import storage`, `import query` inside handlers). Tests run with `src/` on path and no cloud `storage` module unless testing infra.

## Build / deploy

1. `bin/build.sh` rsyncs `src/` + `infra/<cloud>/python/` into a staging dir, zips to `dist/`.
2. Terraform in each cloud uses `abspath(../../../dist/<cloud>/function.zip)`.
3. **Always build before apply** if Python changed.
4. Peer URLs: deploy all clouds first, then `bin/wire-peers.sh` (writes `peers.auto.tfvars.json` per cloud).

## Runtime entry points (inside zip root, not repo root)

| Cloud | File | Symbol | Terraform |
|-------|------|--------|-----------|
| AWS | `main.py` | `handler` | `handler = "main.handler"` |
| GCP | `main.py` | `health` | `entry_point = "health"` |
| Azure | `function_app.py` | `app` | filename fixed by Azure v2 model |

Never name cloud adapter module `http.py` — shadows stdlib `http` and breaks `urllib`.

## Blob storage facade

Each cloud has `blob.py` + `storage.py`:

- `blob.from_env()` reads `BLOB_URI`
- `storage.write_event(record)` uses hive paths from `src/models.py`
- DuckDB query only on AWS (`query.py` + S3 `duckdb_glob`)

## Credentials (`bin/load-env.sh`)

- **AWS:** `aws configure export-credentials` when keys empty; tokens expire — re-source before long terraform runs.
- **GCP:** `GCP_PROJECT_ID` + `GOOGLE_OAUTH_ACCESS_TOKEN` from gcloud.
- **Azure:** `ARM_*` from `az account show`; `AZURE_STORAGE_CONNECTION_STRING` set in terraform for blob writes.

Never commit `.env`, `terraform.tfvars`, or `peers.auto.tfvars.json`.

## Tests

```bash
uv run pytest tests/
```

- `tests/test_core.py` — `src/` routes (no cloud storage).
- `tests/test_blob.py` — AWS `S3BlobStore` URI parsing only.

## Lessons learned (do not repeat)

1. **GCP import paths:** zip root is package root — use `from src.app` not `from function.app`.
2. **GCP `main.py`:** must define `health` inline; do not import excluded `gcp_main.py`.
3. **Azure deps:** `WEBSITE_RUN_FROM_PACKAGE` does not run Oryx pip — vendor into `.python_packages` at build time with **manylinux py3.12** wheels.
4. **Unified terraform → per-cloud:** state does not migrate; destroy old or import manually.
5. **FUNC layout:** `src/` = BL, `infra/` = multi-cloud; avoid DDD ceremony for this size.
6. **`adapter.py` not `http.py`:** prevents stdlib shadowing during tests.

## Self-update

After non-trivial deploy/debug sessions, append dated bullets under **Lessons learned** or fix outdated commands here.
