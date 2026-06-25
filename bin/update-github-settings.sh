#!/usr/bin/env bash
# Update GitHub repository description and topics.
# Usage: ./bin/update-github-settings.sh

set -euo pipefail

REPO="eSlider/aws-gcp-azure"

if ! gh auth status &>/dev/null; then
  echo "GitHub CLI is not authenticated. Run: gh auth login" >&2
  exit 1
fi

DESCRIPTION="One Python serverless app on AWS Lambda, GCP Cloud Functions, and Azure Functions — webhooks, hive blob storage, peer sync, DuckDB query."

TOPICS=(
  python
  aws
  gcp
  azure
  serverless
  lambda
  terraform
  multi-cloud
  webhooks
  duckdb
  cloud-functions
  azure-functions
)

echo "Updating $REPO ..."
gh repo edit "$REPO" --description "$DESCRIPTION"

for topic in "${TOPICS[@]}"; do
  gh repo edit "$REPO" --add-topic "$topic" || echo "warn: could not add topic $topic" >&2
done

gh repo view "$REPO" --json description,homepageUrl,repositoryTopics,visibility,defaultBranchRef | python3 - <<'PY'
import json, sys
data = json.load(sys.stdin)
print(json.dumps({
    "description": data.get("description"),
    "homepageUrl": data.get("homepageUrl"),
    "topics": [t["name"] for t in (data.get("repositoryTopics") or [])],
    "visibility": data.get("visibility"),
    "defaultBranch": (data.get("defaultBranchRef") or {}).get("name"),
}, indent=2))
PY
