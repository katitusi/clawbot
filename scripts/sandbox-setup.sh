#!/usr/bin/env bash
# =============================================================================
# Build Sandbox Images
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building sandbox images..."

# Base sandbox
echo "==> Building openclaw-sandbox:bookworm-slim"
docker build -t "openclaw-sandbox:bookworm-slim" -f "$ROOT_DIR/Dockerfile.sandbox" "$ROOT_DIR"

# Browser sandbox
echo "==> Building openclaw-sandbox-browser:bookworm-slim"
docker build -t "openclaw-sandbox-browser:bookworm-slim" -f "$ROOT_DIR/Dockerfile.sandbox-browser" "$ROOT_DIR"

echo ""
echo "Done! Sandbox images built:"
echo "  - openclaw-sandbox:bookworm-slim"
echo "  - openclaw-sandbox-browser:bookworm-slim"
echo ""
echo "To use in openclaw.json:"
echo '  agents.defaults.sandbox.docker.image = "openclaw-sandbox:bookworm-slim"'
