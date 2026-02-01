#!/usr/bin/env bash
# =============================================================================
# Health Check Script
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

PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"

echo "Checking OpenClaw Gateway health..."
echo ""

# Check if container is running
if docker compose ps openclaw-gateway | grep -q "Up"; then
    echo "✅ Container: Running"
else
    echo "❌ Container: Not running"
    exit 1
fi

# Check HTTP endpoint
if curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
    echo "✅ HTTP Health: OK"
else
    echo "❌ HTTP Health: Failed"
fi

# Check gateway health command
if [[ -n "$TOKEN" ]]; then
    if docker compose exec -T openclaw-gateway node dist/index.js health --token "$TOKEN" >/dev/null 2>&1; then
        echo "✅ Gateway Health: OK"
    else
        echo "⚠️  Gateway Health: Check failed (may still be starting)"
    fi
fi

echo ""
echo "Container status:"
docker compose ps openclaw-gateway

echo ""
echo "Recent logs:"
docker compose logs --tail=10 openclaw-gateway
