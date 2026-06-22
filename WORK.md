# Deployments

Last updated: 2026-06-22 (pre-refactor baseline)

| Cloud | Status | Base URL | Blob |
|-------|--------|----------|------|
| **AWS** | Live | https://1wd4tjs2c9.execute-api.eu-central-1.amazonaws.com | (none yet) |
| **Azure** | Live | https://minimalhealthfn.azurewebsites.net/api | (none yet) |
| **GCP** | Live | https://minimal-health-health-g7j55xrhvq-uc.a.run.app | (none yet) |

## Endpoints (current)

- `GET /health` → `{"status":"ok"}`

## Smoke test

```bash
curl -s https://1wd4tjs2c9.execute-api.eu-central-1.amazonaws.com/health
curl -s https://minimalhealthfn.azurewebsites.net/api/health
curl -s https://minimal-health-health-g7j55xrhvq-uc.a.run.app
```
