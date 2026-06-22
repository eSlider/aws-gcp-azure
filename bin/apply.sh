#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1090
source "$ROOT/bin/load-env.sh"

bash "$ROOT/bin/build.sh" all

apply_cloud() {
  local cloud="$1"
  local tf_dir="$ROOT/infra/$cloud/terraform"
  [[ -d "$tf_dir" ]] || return 0
  echo "=== apply $cloud ==="
  cd "$tf_dir"
  terraform init -input=false
  case "$cloud" in
    aws)
      terraform apply -auto-approve -input=false \
        -var="resource_prefix=${RESOURCE_PREFIX}" \
        -var="aws_region=${AWS_REGION}"
      ;;
    gcp)
      [[ -n "${GCP_PROJECT_ID:-}" ]] || { echo "skip gcp: GCP_PROJECT_ID unset"; return 0; }
      terraform apply -auto-approve -input=false \
        -var="resource_prefix=${RESOURCE_PREFIX}" \
        -var="gcp_project_id=${GCP_PROJECT_ID}" \
        -var="gcp_region=${GCP_REGION}"
      ;;
    az)
      terraform apply -auto-approve -input=false \
        -var="resource_prefix=${RESOURCE_PREFIX}" \
        -var="azure_location=${AZURE_LOCATION}"
      ;;
  esac
}

apply_cloud aws
apply_cloud gcp
apply_cloud az
