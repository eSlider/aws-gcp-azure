#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1090
source "$ROOT/bin/load-env.sh"

AWS="$(terraform -chdir="$ROOT/infra/aws/terraform" output -raw base_url 2>/dev/null || true)"
GCP="$(terraform -chdir="$ROOT/infra/gcp/terraform" output -raw base_url 2>/dev/null || true)"
AZ="$(terraform -chdir="$ROOT/infra/az/terraform" output -raw base_url 2>/dev/null || true)"

apply_peers() {
  local cloud="$1"
  local json="$2"
  local tf_dir="$ROOT/infra/$cloud/terraform"
  [[ -d "$tf_dir/.terraform" ]] || return 0
  printf '%s\n' "$json" > "$tf_dir/peers.auto.tfvars.json"
  echo "wrote infra/$cloud/terraform/peers.auto.tfvars.json"
  cd "$tf_dir"
  case "$cloud" in
    aws)
      terraform apply -auto-approve -input=false \
        -var="resource_prefix=${RESOURCE_PREFIX}" \
        -var="aws_region=${AWS_REGION}"
      ;;
    gcp)
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

AWS_PEERS=$(python3 - <<EOF
import json
print(json.dumps({"lambda_peer_urls": [u for u in ["$GCP", "$AZ"] if u]}))
EOF
)
GCP_PEERS=$(python3 - <<EOF
import json
print(json.dumps({"lambda_peer_urls": [u for u in ["$AWS", "$AZ"] if u]}))
EOF
)
AZ_PEERS=$(python3 - <<EOF
import json
print(json.dumps({"lambda_peer_urls": [u for u in ["$AWS", "$GCP"] if u]}))
EOF
)

apply_peers aws "$AWS_PEERS"
apply_peers gcp "$GCP_PEERS"
apply_peers az "$AZ_PEERS"
