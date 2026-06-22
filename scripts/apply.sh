#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1090
source "$ROOT/scripts/load-env.sh"
cd "$ROOT/terraform"
terraform init -input=false
terraform apply -auto-approve -input=false "$@"
