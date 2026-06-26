#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITLAB_DIR="$(cd "$SCRIPT_DIR/../gitlab" && pwd)"
ECOSYSTEM_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MCP_ENV_FILE="$SCRIPT_DIR/.env.local"
DEFAULT_STITCH_MCP_URL="https://stitch.googleapis.com/mcp"

echo "=== MegaDev MCP Server Setup ==="

if [ -f "$MCP_ENV_FILE" ]; then
    echo "Loading local MCP settings from $MCP_ENV_FILE"
    # shellcheck disable=SC1090
    set -a
    source "$MCP_ENV_FILE"
    set +a
fi

# Read GitLab token
GITLAB_TOKEN=$(cat "$GITLAB_DIR/.gitlab-token" 2>/dev/null || echo "")
if [ -z "$GITLAB_TOKEN" ]; then
    echo "ERROR: No GitLab token found. Run setup-gitlab.sh first."
    exit 1
fi

# Install MCP server packages
echo "Installing GitLab MCP server..."
if npm install -g @zereight/mcp-gitlab >/dev/null 2>&1; then
    echo "GitLab MCP server installed globally."
else
    echo "Global install skipped; Claude/Codex will launch the GitLab MCP server via npx."
fi

# Configure Claude Code MCP servers
echo "Configuring Claude Code MCP servers..."

STITCH_MCP_URL="${STITCH_MCP_URL:-$DEFAULT_STITCH_MCP_URL}"
STITCH_BLOCK=""
if [ -n "${STITCH_API_KEY:-}" ]; then
    STITCH_BLOCK=$(cat <<EOF
,
    "stitch": {
      "type": "http",
      "url": "$STITCH_MCP_URL",
      "headers": {
        "X-Goog-Api-Key": "$STITCH_API_KEY"
      }
    }
EOF
)
fi

# Create the MCP config for the project
cat > "$ECOSYSTEM_DIR/.mcp.json" << MCPEOF
{
  "mcpServers": {
    "gitlab": {
      "command": "npx",
      "args": ["-y", "@zereight/mcp-gitlab"],
      "env": {
        "GITLAB_API_URL": "http://localhost:8929/api/v4",
        "GITLAB_PERSONAL_ACCESS_TOKEN": "$GITLAB_TOKEN"
      }
    }$STITCH_BLOCK
  }
}
MCPEOF

echo "MCP configuration written to $ECOSYSTEM_DIR/.mcp.json"

echo ""
echo "=== MCP Setup Complete ==="
echo "Configured servers:"
echo "  - GitLab MCP (localhost:8929)"
if [ -n "${STITCH_API_KEY:-}" ]; then
    echo "  - Stitch MCP ($STITCH_MCP_URL)"
else
    echo "  - Stitch MCP not configured"
    echo "    Add STITCH_API_KEY to $MCP_ENV_FILE and rerun this script."
fi
echo ""
echo "To verify: cd $ECOSYSTEM_DIR && claude mcp list"
