#!/usr/bin/env bash
# =============================================================================
# Backup OpenClaw Configuration
# =============================================================================

set -euo pipefail

# Configuration
OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/openclaw-backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/openclaw-backup-$TIMESTAMP.tar.gz"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Creating backup of OpenClaw configuration..."
echo "Source: $OPENCLAW_CONFIG_DIR"
echo "Destination: $BACKUP_FILE"

# Create backup (excluding large cache files)
tar -czf "$BACKUP_FILE" \
    --exclude='*.log' \
    --exclude='cache/*' \
    --exclude='node_modules/*' \
    -C "$(dirname "$OPENCLAW_CONFIG_DIR")" \
    "$(basename "$OPENCLAW_CONFIG_DIR")"

echo ""
echo "Backup created: $BACKUP_FILE"
echo "Size: $(du -h "$BACKUP_FILE" | cut -f1)"

# Keep only last 10 backups
echo ""
echo "Cleaning old backups (keeping last 10)..."
ls -t "$BACKUP_DIR"/openclaw-backup-*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -v

echo ""
echo "Done!"
