#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-all}"

build_cloud() {
  local cloud="$1"
  local staging
  staging="$(mktemp -d)"

  rsync -a --exclude '__pycache__' --exclude '*.pyc' \
    "$ROOT/src/" "$staging/src/"
  rsync -a --exclude '__pycache__' --exclude '*.pyc' \
    "$ROOT/infra/$cloud/python/" "$staging/"

  if [[ "$cloud" == "az" ]]; then
    uv pip install -q -r "$staging/requirements.txt" \
      --target "$staging/.python_packages/lib/site-packages" \
      --python-platform x86_64-manylinux_2_28 \
      --python-version 3.12 \
      --only-binary :all:
  fi

  mkdir -p "$ROOT/dist/$cloud"
  rm -f "$ROOT/dist/$cloud/function.zip"
  (cd "$staging" && zip -qr "$ROOT/dist/$cloud/function.zip" .)
  rm -rf "$staging"
  echo "built dist/$cloud/function.zip"
}

case "$TARGET" in
  aws|gcp|az) build_cloud "$TARGET" ;;
  all) build_cloud aws; build_cloud gcp; build_cloud az ;;
  *) echo "usage: $0 [aws|gcp|az|all]" >&2; exit 1 ;;
esac
