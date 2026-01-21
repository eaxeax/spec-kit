#!/usr/bin/env bash
set -euo pipefail

# Build local Spec Kit release archives from templates-beads/.
#
# Usage:
#   ./make-beads-template.sh v0.0.0-local
#
# Output:
#   .genreleases/spec-kit-template-<agent>-<script>-<version>.zip

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="$SCRIPT_DIR"

VERSION=${1:-v0.0.0-local}

export AGENTS="opencode,claude"
export TEMPLATES_DIR="templates-beads"

(
  cd "$REPO_ROOT"
  .github/workflows/scripts/create-release-packages.sh "$VERSION"
)
