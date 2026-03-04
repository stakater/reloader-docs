#!/usr/bin/env bash
# Run the dispatch workflow using gh CLI against a specific ref (branch)
# Usage: ./scripts/run-dispatch.sh [ref] [version]
# Requires: gh CLI authenticated, base64

set -euo pipefail

REF=${1:-update-docs-workflow}
VERSION=${2:-v1.2.3}
IMAGE_PATH=${3:-ghcr.io/stakater/reloader-enterprise}
SBOM_FILE=${4:-content/sbom.json}

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required. Install from https://github.com/cli/cli"
  exit 1
fi

if [ ! -f "$SBOM_FILE" ]; then
  echo "SBOM file not found: $SBOM_FILE"
  exit 1
fi

# Encode SBOM without line-wraps (portable)
if base64 --help 2>/dev/null | grep -q -- '-w'; then
  SBOM_B64=$(base64 -w0 "$SBOM_FILE")
else
  SBOM_B64=$(base64 "$SBOM_FILE" | tr -d '\n')
fi

echo "Triggering workflow dispatch on ref=$REF with version=$VERSION"

gh workflow run dispatch.yaml \
  --repo stakater/reloader-enterprise-package-proxy \
  --ref "$REF" \
  --field version="$VERSION" \
  --field path="$IMAGE_PATH" \
  --field sbom_64="$SBOM_B64"

echo "Dispatched. Use 'gh run list --repo stakater/reloader-enterprise-package-proxy' to follow the run." 
