#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck disable=SC1090
source "${ROOT_DIR}/scripts/load-env.sh"

PROJECT="${GCP_PROJECT_ID:-idyllic-volt-437916-n6}"

BILLING="$(gcloud billing projects describe "${PROJECT}" --format='value(billingEnabled)' 2>/dev/null || echo false)"
if [[ "${BILLING}" != "True" ]]; then
  echo "GCP billing is not enabled on project ${PROJECT}." >&2
  echo "Enable it: https://console.cloud.google.com/billing/linkedaccount?project=${PROJECT}" >&2
  exit 1
fi

export GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)"

cd "${ROOT_DIR}/terraform/gcp"
terraform apply -auto-approve -var="gcp_project_id=${PROJECT}"

URL="$(terraform output -raw function_url)"
echo ""
echo "GCP URL: ${URL}"
curl -sS "${URL}" && echo ""
