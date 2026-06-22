#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/terraform"

AWS=$(terraform output -json lambda_urls | python3 -c "import sys,json; u=json.load(sys.stdin); print(u.get('aws') or '')")
GCP=$(terraform output -json lambda_urls | python3 -c "import sys,json; u=json.load(sys.stdin); print(u.get('gcp') or '')")
AZ=$(terraform output -json lambda_urls | python3 -c "import sys,json; u=json.load(sys.stdin); print(u.get('azure') or '')")

PEERS=$(python3 - <<EOF
import json
peers = {"aws": [], "gcp": [], "azure": []}
if "$GCP": peers["aws"].append("$GCP")
if "$AZ": peers["aws"].append("$AZ")
if "$AWS": peers["gcp"].append("$AWS")
if "$AZ": peers["gcp"].append("$AZ")
if "$AWS": peers["azure"].append("$AWS")
if "$GCP": peers["azure"].append("$GCP")
print(json.dumps(peers))
EOF
)

cat > peers.auto.tfvars.json <<EOF
{"lambda_peer_urls": $PEERS}
EOF
echo "Wrote peers.auto.tfvars.json"
terraform apply -auto-approve -input=false
