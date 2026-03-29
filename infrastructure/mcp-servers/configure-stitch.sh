#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.local"
STITCH_API_KEY="${1:-}"
STITCH_MCP_URL="${2:-https://stitch.googleapis.com/mcp}"

if [ -z "$STITCH_API_KEY" ]; then
    echo "Usage: $0 <stitch-api-key> [stitch-mcp-url]"
    exit 1
fi

{
    echo "# Local-only MCP secrets. This file is gitignored."
    printf 'STITCH_API_KEY=%q\n' "$STITCH_API_KEY"
    printf 'STITCH_MCP_URL=%q\n' "$STITCH_MCP_URL"
} > "$ENV_FILE"

chmod 600 "$ENV_FILE"
bash "$SCRIPT_DIR/setup-mcp.sh"

echo ""
echo "Stitch MCP configured."
echo "Local secrets file: $ENV_FILE"
