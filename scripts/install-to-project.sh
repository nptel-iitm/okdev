#!/usr/bin/env bash
set -euo pipefail

# Install AgentForge skills and config into a target project
# Usage: ./install-to-project.sh /path/to/your/project

ECOSYSTEM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${1:?Usage: $0 /path/to/your/project}"

if [ ! -d "$TARGET_DIR" ]; then
    echo "ERROR: Target directory does not exist: $TARGET_DIR"
    exit 1
fi

echo "Installing AgentForge into: $TARGET_DIR"

# Copy skills
echo "  Copying skills..."
mkdir -p "$TARGET_DIR/.claude/skills"
cp -r "$ECOSYSTEM_DIR/.claude/skills/"* "$TARGET_DIR/.claude/skills/"

# Copy hooks config
echo "  Copying hooks configuration..."
mkdir -p "$TARGET_DIR/.claude"
cp "$ECOSYSTEM_DIR/.claude/settings.json" "$TARGET_DIR/.claude/settings.json"

# Copy CLAUDE.md (append if exists)
if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
    echo "  Appending to existing CLAUDE.md..."
    echo "" >> "$TARGET_DIR/CLAUDE.md"
    echo "---" >> "$TARGET_DIR/CLAUDE.md"
    echo "" >> "$TARGET_DIR/CLAUDE.md"
    cat "$ECOSYSTEM_DIR/CLAUDE.md" >> "$TARGET_DIR/CLAUDE.md"
else
    echo "  Copying CLAUDE.md..."
    cp "$ECOSYSTEM_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
fi

# Copy MCP config
echo "  Copying MCP config..."
if [ -f "$ECOSYSTEM_DIR/.mcp.json" ]; then
    cp "$ECOSYSTEM_DIR/.mcp.json" "$TARGET_DIR/.mcp.json"
else
    echo "  WARNING: No .mcp.json found. Run setup-all.sh first."
fi

# Create .agentforge directory for runtime artifacts
mkdir -p "$TARGET_DIR/.agentforge/test-results/screenshots/{e2e,ui,manual}"

echo ""
echo "AgentForge installed to $TARGET_DIR"
echo ""
echo "Available skills:"
find "$TARGET_DIR/.claude/skills" -name "SKILL.md" | sort | while read f; do
    skill_name=$(grep "^name:" "$f" | head -1 | sed 's/name: //')
    echo "  • $skill_name"
done
echo ""
echo "To start: cd $TARGET_DIR && claude && /kickoff"
