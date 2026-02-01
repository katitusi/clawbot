#!/usr/bin/env bash
# =============================================================================
# Stop OpenClaw Gateway
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "Stopping OpenClaw Gateway..."
docker compose down

echo "Gateway stopped."
