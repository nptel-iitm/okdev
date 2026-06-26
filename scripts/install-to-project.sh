#!/usr/bin/env bash
set -euo pipefail

# Install MegaDev skills and config into a target project
# Usage: ./install-to-project.sh /path/to/your/project

ECOSYSTEM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${1:?Usage: $0 /path/to/your/project}"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CODEX_SKILLS_DIR="$CODEX_HOME_DIR/skills"
BACKUP_ROOT="$CODEX_HOME_DIR/megadev-backups"

ensure_ignore_entry() {
    local ignore_file="$1"
    local pattern="$2"

    if [ ! -f "$ignore_file" ]; then
        printf '%s\n' "$pattern" > "$ignore_file"
        return
    fi

    if ! grep -Fxq "$pattern" "$ignore_file"; then
        printf '\n%s\n' "$pattern" >> "$ignore_file"
    fi
}

if [ ! -d "$TARGET_DIR" ]; then
    echo "ERROR: Target directory does not exist: $TARGET_DIR"
    exit 1
fi

echo "Installing MegaDev into: $TARGET_DIR"

# Copy Claude skills
echo "  Copying Claude skills..."
mkdir -p "$TARGET_DIR/.claude/skills"
cp -r "$ECOSYSTEM_DIR/.claude/skills/"* "$TARGET_DIR/.claude/skills/"

# Copy Codex skills
echo "  Copying Codex skills..."
mkdir -p "$CODEX_SKILLS_DIR"
for skill_dir in "$ECOSYSTEM_DIR"/.claude/skills/*; do
    skill_name="$(basename "$skill_dir")"
    target_skill_dir="$CODEX_SKILLS_DIR/$skill_name"

    if [ -e "$target_skill_dir" ]; then
        backup_dir="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)/$skill_name"
        echo "    Existing Codex skill '$skill_name' found; backing it up to $backup_dir"
        mkdir -p "$(dirname "$backup_dir")"
        cp -r "$target_skill_dir" "$backup_dir"
        rm -rf "$target_skill_dir"
    fi

    cp -r "$skill_dir" "$target_skill_dir"
done

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
echo "  Refreshing MCP config from local settings..."
if bash "$ECOSYSTEM_DIR/infrastructure/mcp-servers/setup-mcp.sh" >/dev/null 2>&1; then
    echo "    MCP config refreshed."
else
    echo "    WARNING: Failed to refresh MCP config. Using existing .mcp.json if available."
fi

if [ -f "$ECOSYSTEM_DIR/.mcp.json" ]; then
    cp "$ECOSYSTEM_DIR/.mcp.json" "$TARGET_DIR/.mcp.json"
    ensure_ignore_entry "$TARGET_DIR/.gitignore" ".mcp.json"
else
    echo "  WARNING: No .mcp.json found. Run setup-all.sh first."
fi

# Create .megadev directory for runtime artifacts
mkdir -p "$TARGET_DIR/.megadev/test-results/screenshots/{e2e,ui,manual}"

echo ""
echo "MegaDev installed to $TARGET_DIR"
echo ""
echo "Available skills:"
find "$ECOSYSTEM_DIR/.claude/skills" -name "SKILL.md" | sort | while read f; do
    skill_name=$(grep "^name:" "$f" | head -1 | sed 's/name: //')
    echo "  • $skill_name"
done
echo ""
echo "Installed for Claude Code in: $TARGET_DIR/.claude/skills"
echo "Installed for Codex in: $CODEX_SKILLS_DIR"
echo "Existing conflicting Codex skills are backed up under: $BACKUP_ROOT"
echo ""
echo "To start with Claude: cd $TARGET_DIR && claude && /kickoff"
echo "To start with Codex:  cd $TARGET_DIR && codex"
echo '  then invoke $kickoff'
echo ""
echo "If Codex was already running, restart it to pick up the new skills."
