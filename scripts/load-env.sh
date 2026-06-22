#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

export AWS_REGION="${AWS_REGION:-eu-central-1}"
export AWS_DEFAULT_REGION="${AWS_REGION}"
export GCP_REGION="${GCP_REGION:-us-central1}"
export AZURE_LOCATION="${AZURE_LOCATION:-westeurope}"
export AZURE_TENANT_ID="${AZURE_TENANT_ID:-}"
export RESOURCE_PREFIX="${RESOURCE_PREFIX:-minimal-health}"

# --- AWS: use CLI login session when static keys are not set ---
if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]] && command -v aws >/dev/null 2>&1; then
  if aws sts get-caller-identity >/dev/null 2>&1; then
    # shellcheck disable=SC1090
    eval "$(aws configure export-credentials --format env 2>/dev/null || true)"
    if [[ -z "${AWS_ACCOUNT_ID:-}" ]]; then
      export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
    fi
    echo "AWS: loaded session for account ${AWS_ACCOUNT_ID:-unknown} (${AWS_REGION})"
  else
    echo "AWS: not authenticated — run 'aws login' or set keys in .env" >&2
  fi
else
  export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
  export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
  export AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-}"
  echo "AWS: using credentials from .env (${AWS_REGION})"
fi

# --- GCP: project + ADC from gcloud ---
if command -v gcloud >/dev/null 2>&1; then
  if [[ -z "${GCP_PROJECT_ID:-}" || "${GCP_PROJECT_ID}" == "(unset)" ]]; then
    GCP_PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
    if [[ -z "${GCP_PROJECT_ID}" || "${GCP_PROJECT_ID}" == "(unset)" ]]; then
      GCP_PROJECT_ID="$(gcloud projects list --format='value(projectId)' --sort-by=projectId --limit=1 2>/dev/null || true)"
      if [[ -n "${GCP_PROJECT_ID}" ]]; then
        echo "GCP: auto-selected project ${GCP_PROJECT_ID} — set GCP_PROJECT_ID in .env to override" >&2
      fi
    fi
    export GCP_PROJECT_ID
  fi

  if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" || ! -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
    ADC="${HOME}/.config/gcloud/application_default_credentials.json"
    if [[ -f "${ADC}" ]]; then
      export GOOGLE_APPLICATION_CREDENTIALS="${ADC}"
    fi
  fi

  GCP_ACCOUNT="$(gcloud config get-value account 2>/dev/null || true)"
  echo "GCP: account=${GCP_ACCOUNT:-unknown} project=${GCP_PROJECT_ID:-unset} region=${GCP_REGION}"
  if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" || ! -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
    echo "GCP: no ADC — run 'gcloud auth application-default login' for Terraform" >&2
  fi
else
  echo "GCP: gcloud not found" >&2
fi

# --- Azure: subscription/tenant from az CLI when logged in ---
if command -v az >/dev/null 2>&1; then
  if az account show >/dev/null 2>&1; then
    [[ -z "${ARM_SUBSCRIPTION_ID:-}" ]] && export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
    [[ -z "${ARM_TENANT_ID:-}" ]] && export ARM_TENANT_ID="$(az account show --query tenantId -o tsv)"
    AZURE_NAME="$(az account show --query name -o tsv)"
    echo "Azure: subscription=${AZURE_NAME} (${ARM_SUBSCRIPTION_ID}) location=${AZURE_LOCATION}"
  else
    echo "Azure: not logged in — run: az login --tenant ${AZURE_TENANT_ID:-<tenant-id>}" >&2
  fi
  export ARM_SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID:-}"
  export ARM_TENANT_ID="${ARM_TENANT_ID:-}"
  export ARM_CLIENT_ID="${ARM_CLIENT_ID:-}"
  export ARM_CLIENT_SECRET="${ARM_CLIENT_SECRET:-}"
else
  echo "Azure: az not found" >&2
fi

echo "Environment ready. RESOURCE_PREFIX=${RESOURCE_PREFIX}"
