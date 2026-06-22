#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1090
source "$ROOT/scripts/load-env.sh"
cd "$ROOT/terraform"
terraform destroy -auto-approve -input=false "$@"
