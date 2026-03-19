#!/usr/bin/env bash
set -euo pipefail

ECOSYSTEM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "============================================"
echo "  AgentForge — Full System Setup"
echo "============================================"
echo ""

# Step 1: Make all scripts executable
echo "[1/5] Making scripts executable..."
chmod +x "$ECOSYSTEM_DIR"/hooks/*.sh
chmod +x "$ECOSYSTEM_DIR"/infrastructure/gitlab/setup-gitlab.sh
chmod +x "$ECOSYSTEM_DIR"/infrastructure/mcp-servers/setup-mcp.sh
chmod +x "$ECOSYSTEM_DIR"/scripts/*.sh
echo "  Done."

# Step 2: Install Playwright browsers
echo ""
echo "[2/5] Setting up Playwright..."
if ! npx playwright --version > /dev/null 2>&1; then
    npm install -g playwright
fi
npx playwright install chromium 2>/dev/null || echo "  Playwright chromium may already be installed"
echo "  Done."

# Step 3: Set up GitLab
echo ""
echo "[3/5] Setting up GitLab (this takes 3-5 minutes on first run)..."
bash "$ECOSYSTEM_DIR/infrastructure/gitlab/setup-gitlab.sh"

# Step 4: Set up MCP servers
echo ""
echo "[4/5] Setting up MCP servers..."
bash "$ECOSYSTEM_DIR/infrastructure/mcp-servers/setup-mcp.sh"

# Step 5: Validate environment
echo ""
echo "[5/5] Validating environment..."
bash "$ECOSYSTEM_DIR/hooks/env-validator.sh"

echo ""
echo "============================================"
echo "  AgentForge Setup Complete!"
echo "============================================"
echo ""
echo "Directory structure:"
find "$ECOSYSTEM_DIR/.claude/skills" -name "SKILL.md" | sort | while read f; do
    skill_name=$(grep "^name:" "$f" | head -1 | sed 's/name: //')
    echo "  📋 $skill_name — $(dirname "$f" | xargs basename)"
done
echo ""
echo "To start a project:"
echo "  Claude: cd your-project-dir && claude && /kickoff"
echo "  Codex:  cd your-project-dir && codex"
echo "          then invoke \$kickoff"
echo ""
echo "GitLab: http://gitlab.local:8929 (root / AgentForge2024!)"
