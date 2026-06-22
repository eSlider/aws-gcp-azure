#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1090
source "$ROOT/bin/load-env.sh"

destroy_cloud() {
  local cloud="$1"
  local tf_dir="$ROOT/infra/$cloud/terraform"
  [[ -d "$tf_dir/.terraform" ]] || return 0
  echo "=== destroy $cloud ==="
  cd "$tf_dir"
  terraform destroy -auto-approve -input=false \
    -var="resource_prefix=${RESOURCE_PREFIX}" \
    ${GCP_PROJECT_ID:+-var="gcp_project_id=${GCP_PROJECT_ID}"} \
    -var="aws_region=${AWS_REGION}" \
    -var="azure_location=${AZURE_LOCATION}" 2>/dev/null || \
  terraform destroy -auto-approve -input=false
}

destroy_cloud aws
destroy_cloud gcp
destroy_cloud az
