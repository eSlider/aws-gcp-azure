#!/usr/bin/env bash
# Print cloud account info from installed CLIs (read-only).
set -euo pipefail

echo "=== AWS ==="
if command -v aws >/dev/null 2>&1 && aws sts get-caller-identity >/dev/null 2>&1; then
  aws sts get-caller-identity
  echo "region: $(aws configure get region 2>/dev/null || echo unknown)"
else
  echo "Not authenticated (run: aws login)"
fi

echo ""
echo "=== GCP ==="
if command -v gcloud >/dev/null 2>&1; then
  echo "account: $(gcloud config get-value account 2>/dev/null)"
  echo "active project: $(gcloud config get-value project 2>/dev/null)"
  echo "ADC: $([[ -f "${HOME}/.config/gcloud/application_default_credentials.json" ]] && echo yes || echo no — run: gcloud auth application-default login)"
  echo "billing accounts:"
  gcloud billing accounts list 2>/dev/null || echo "  (none or no permission)"
  echo "projects:"
  gcloud projects list --format="table(projectId,name)" 2>/dev/null | head -15
else
  echo "gcloud not installed"
fi

echo ""
echo "=== Azure ==="
if command -v az >/dev/null 2>&1 && az account show >/dev/null 2>&1; then
  az account show --query "{name:name, subscriptionId:id, tenantId:tenantId, state:state}" -o table
else
  echo "Not logged in (run: az login)"
fi
