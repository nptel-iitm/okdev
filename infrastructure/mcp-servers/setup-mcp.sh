#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITLAB_DIR="$(cd "$SCRIPT_DIR/../gitlab" && pwd)"
ECOSYSTEM_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== AgentForge MCP Server Setup ==="

# Read GitLab token
GITLAB_TOKEN=$(cat "$GITLAB_DIR/.gitlab-token" 2>/dev/null || echo "")
if [ -z "$GITLAB_TOKEN" ]; then
    echo "ERROR: No GitLab token found. Run setup-gitlab.sh first."
    exit 1
fi

# Install MCP server packages
echo "Installing GitLab MCP server..."
npm install -g @zereight/mcp-gitlab 2>/dev/null || npx -y @zereight/mcp-gitlab --version

# Configure Claude Code MCP servers
echo "Configuring Claude Code MCP servers..."

# Create the MCP config for the project
cat > "$ECOSYSTEM_DIR/.mcp.json" << MCPEOF
{
  "mcpServers": {
    "gitlab": {
      "command": "npx",
      "args": ["-y", "@zereight/mcp-gitlab"],
      "env": {
        "GITLAB_API_URL": "http://localhost:8929/api/v4",
        "GITLAB_TOKEN": "$GITLAB_TOKEN"
      }
    }
  }
}
MCPEOF

echo "MCP configuration written to $ECOSYSTEM_DIR/.mcp.json"

echo ""
echo "=== MCP Setup Complete ==="
echo "Configured servers:"
echo "  - GitLab MCP (localhost:8929)"
echo ""
echo "To verify: claude --mcp-debug"
