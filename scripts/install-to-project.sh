#!/usr/bin/env bash
set -euo pipefail

# Install OKDev into a target project, for Claude Code, for Codex, or for both.
#
#   ./install-to-project.sh /path/to/project                 # asks which harness
#   ./install-to-project.sh /path/to/project --harness codex # or claude, or both
#
# The two harnesses get different skill trees on purpose. They are not
# translations of each other: Codex drops a skill between turns and compacts
# long runs, so its skills keep their phase and loop counters in
# .okdev/run-state.json and end in states an agent can reach without a human.
# Installing the Claude tree for a Codex user is what produced the runaway
# workflows in issue #15.

ECOSYSTEM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR=""
HARNESS=""

while [ $# -gt 0 ]; do
    case "$1" in
        --harness) HARNESS="$2"; shift 2 ;;
        -h|--help)
            sed -n '3,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *)
            if [ -z "$TARGET_DIR" ]; then TARGET_DIR="$1"; shift
            else echo "install: unexpected argument $1" >&2; exit 2; fi ;;
    esac
done

if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 /path/to/your/project [--harness claude|codex|both]" >&2
    exit 2
fi
if [ ! -d "$TARGET_DIR" ]; then
    echo "ERROR: Target directory does not exist: $TARGET_DIR" >&2
    exit 1
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

if [ -z "$HARNESS" ]; then
    if [ ! -t 0 ]; then
        echo "ERROR: no --harness given and stdin is not a terminal." >&2
        echo "       Pass --harness claude|codex|both." >&2
        exit 2
    fi
    echo "Which agent will you run OKDev with?"
    echo "  1) Claude Code"
    echo "  2) Codex"
    echo "  3) Both"
    printf 'Choice [1/2/3]: '
    read -r choice
    case "$choice" in
        1) HARNESS="claude" ;;
        2) HARNESS="codex" ;;
        3) HARNESS="both" ;;
        *) echo "ERROR: choose 1, 2 or 3." >&2; exit 2 ;;
    esac
fi

case "$HARNESS" in
    claude|codex|both) ;;
    *) echo "ERROR: --harness must be claude, codex or both (got '$HARNESS')" >&2; exit 2 ;;
esac

CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CODEX_SKILLS_DIR="$CODEX_HOME_DIR/skills"
BACKUP_ROOT="$CODEX_HOME_DIR/okdev-backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

echo "Installing OKDev into: $TARGET_DIR"
echo "Harness: $HARNESS"

ensure_ignore_entry() {
    local ignore_file="$1" pattern="$2"
    if [ ! -f "$ignore_file" ]; then
        printf '%s\n' "$pattern" > "$ignore_file"
    elif ! grep -Fxq "$pattern" "$ignore_file"; then
        printf '\n%s\n' "$pattern" >> "$ignore_file"
    fi
}

# Replace a skill tree, keeping a timestamped copy of anything already there.
install_skills() {
    local src="$1" dest="$2"
    mkdir -p "$dest"
    for skill_dir in "$src"/*; do
        [ -d "$skill_dir" ] || continue
        local name target
        name="$(basename "$skill_dir")"
        target="$dest/$name"
        if [ -e "$target" ]; then
            local backup="$BACKUP_ROOT/$STAMP/$(basename "$dest")/$name"
            mkdir -p "$(dirname "$backup")"
            cp -r "$target" "$backup"
            rm -rf "$target"
        fi
        cp -r "$skill_dir" "$target"
    done
}

install_claude() {
    echo "  Claude skills -> $TARGET_DIR/.claude/skills"
    install_skills "$ECOSYSTEM_DIR/claude/skills" "$TARGET_DIR/.claude/skills"

    mkdir -p "$TARGET_DIR/.claude"
    cp "$ECOSYSTEM_DIR/claude/settings.json" "$TARGET_DIR/.claude/settings.json"

    if [ -f "$TARGET_DIR/CLAUDE.md" ] && ! grep -q "Over Kill Dev" "$TARGET_DIR/CLAUDE.md"; then
        echo "  Appending OKDev rules to the existing CLAUDE.md"
        printf '\n---\n\n' >> "$TARGET_DIR/CLAUDE.md"
        cat "$ECOSYSTEM_DIR/CLAUDE.md" >> "$TARGET_DIR/CLAUDE.md"
    elif [ ! -f "$TARGET_DIR/CLAUDE.md" ]; then
        cp "$ECOSYSTEM_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
    fi
}

install_codex() {
    echo "  Codex skills -> $CODEX_SKILLS_DIR"
    install_skills "$ECOSYSTEM_DIR/codex/skills" "$CODEX_SKILLS_DIR"

    # The durable state helper every Codex skill calls. Without it the skills
    # have nowhere to keep a loop counter that survives a compaction.
    echo "  Run-state helper -> $TARGET_DIR/.okdev/bin/okdev-state"
    echo "  Supervisor       -> $TARGET_DIR/.okdev/bin/okdev-supervise"
    mkdir -p "$TARGET_DIR/.okdev/bin"
    cp "$ECOSYSTEM_DIR/codex/lib/okdev-state" "$TARGET_DIR/.okdev/bin/okdev-state"
    chmod +x "$TARGET_DIR/.okdev/bin/okdev-state"
    cp "$ECOSYSTEM_DIR/codex/lib/okdev-supervise" "$TARGET_DIR/.okdev/bin/okdev-supervise"
    chmod +x "$TARGET_DIR/.okdev/bin/okdev-supervise"

    if [ -f "$TARGET_DIR/AGENTS.md" ] && ! grep -q "Over Kill Dev" "$TARGET_DIR/AGENTS.md"; then
        echo "  Appending OKDev rules to the existing AGENTS.md"
        printf '\n---\n\n' >> "$TARGET_DIR/AGENTS.md"
        cat "$ECOSYSTEM_DIR/codex/AGENTS.md" >> "$TARGET_DIR/AGENTS.md"
    elif [ ! -f "$TARGET_DIR/AGENTS.md" ]; then
        cp "$ECOSYSTEM_DIR/codex/AGENTS.md" "$TARGET_DIR/AGENTS.md"
    fi
}

case "$HARNESS" in
    claude) install_claude ;;
    codex)  install_codex ;;
    both)   install_claude; install_codex ;;
esac

echo "  Refreshing MCP config..."
if bash "$ECOSYSTEM_DIR/infrastructure/mcp-servers/setup-mcp.sh" >/dev/null 2>&1; then
    echo "    MCP config refreshed."
else
    echo "    WARNING: could not refresh MCP config; using existing .mcp.json if present."
fi

if [ -f "$ECOSYSTEM_DIR/.mcp.json" ]; then
    cp "$ECOSYSTEM_DIR/.mcp.json" "$TARGET_DIR/.mcp.json"
    chmod 600 "$TARGET_DIR/.mcp.json"
    ensure_ignore_entry "$TARGET_DIR/.gitignore" ".mcp.json"
else
    echo "  WARNING: no .mcp.json found. Run setup-all.sh first."
fi

mkdir -p \
    "$TARGET_DIR/.okdev/test-results/screenshots/e2e" \
    "$TARGET_DIR/.okdev/test-results/screenshots/ui" \
    "$TARGET_DIR/.okdev/test-results/screenshots/manual"

echo
echo "OKDev installed to $TARGET_DIR"
echo

if [ "$HARNESS" = "claude" ] || [ "$HARNESS" = "both" ]; then
    echo "Claude Code:"
    echo "  skills: $TARGET_DIR/.claude/skills"
    echo "  start:  cd $TARGET_DIR && claude, then /kickoff"
    echo
fi
if [ "$HARNESS" = "codex" ] || [ "$HARNESS" = "both" ]; then
    echo "Codex:"
    echo "  skills: $CODEX_SKILLS_DIR"
    echo "  rules:  $TARGET_DIR/AGENTS.md"
    echo "  state:  $TARGET_DIR/.okdev/bin/okdev-state  (run 'okdev-state next' to see where a run stands)"
    echo "  resume: a stopped run continues by invoking the same skill again in this directory."
    echo "          .okdev/bin/okdev-supervise --skill kickoff --project \"$TARGET_DIR\" retries for you."
    echo "  start:  cd $TARGET_DIR && codex, then \$kickoff"
    echo "  note:   restart Codex if it was already running, so it picks up the skills."
    echo
fi
echo "Replaced skills were backed up under: $BACKUP_ROOT/$STAMP"
