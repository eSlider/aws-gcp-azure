#!/usr/bin/env bash
# Update GitHub repository description and topics.
# Usage: ./bin/update-github-settings.sh

set -euo pipefail

REPO="eSlider/aws-gcp-azure"

if ! gh auth status &>/dev/null; then
  echo "GitHub CLI is not authenticated. Run: gh auth login" >&2
  exit 1
fi

DESCRIPTION="LAMBADA — One Python App on AWS, GCP, and Azure Serverless. Webhooks, hive blob storage, peer sync, DuckDB query."

TOPICS=(
  lambada
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

gh repo view "$REPO" --json description,homepageUrl,repositoryTopics,visibility,defaultBranchRef \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps({"description":d.get("description"),"homepageUrl":d.get("homepageUrl"),"topics":[t["name"] for t in (d.get("repositoryTopics") or [])],"visibility":d.get("visibility"),"defaultBranch":(d.get("defaultBranchRef") or {}).get("name")}, indent=2))'
