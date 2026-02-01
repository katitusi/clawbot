#!/usr/bin/env bash
# =============================================================================
# Start OpenClaw Gateway
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# Load environment
if [[ -f .env ]]; then
    set -a
    source .env
    set +a
fi

echo "Starting OpenClaw Gateway..."
docker compose up -d openclaw-gateway

echo ""
echo "Gateway started!"
echo "Access UI: http://127.0.0.1:${OPENCLAW_GATEWAY_PORT:-18789}/"
echo ""
echo "Useful commands:"
echo "  View logs:    docker compose logs -f openclaw-gateway"
echo "  Stop:         docker compose down"
echo "  CLI:          docker compose run --rm openclaw-cli <command>"
