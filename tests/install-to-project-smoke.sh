#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d /tmp/okdev-installer-test-XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT

TARGET_DIR="$TEST_ROOT/target"
FRESH_TARGET_DIR="$TEST_ROOT/fresh-target"
TEST_CODEX_HOME="$TEST_ROOT/codex-home"
FAKE_BIN="$TEST_ROOT/bin"
ECOSYSTEM_FIXTURE="$TEST_ROOT/ecosystem"
mkdir -p \
    "$TARGET_DIR" \
    "$FRESH_TARGET_DIR" \
    "$TEST_CODEX_HOME/skills/kickoff" \
    "$FAKE_BIN" \
    "$ECOSYSTEM_FIXTURE/scripts" \
    "$ECOSYSTEM_FIXTURE/infrastructure/mcp-servers"

printf 'existing Codex skill\n' > "$TEST_CODEX_HOME/skills/kickoff/backup-sentinel"
cp -r "$REPO_DIR/.claude" "$ECOSYSTEM_FIXTURE/.claude"
cp "$REPO_DIR/CLAUDE.md" "$ECOSYSTEM_FIXTURE/CLAUDE.md"
cp "$REPO_DIR/scripts/install-to-project.sh" "$ECOSYSTEM_FIXTURE/scripts/install-to-project.sh"
cp "$REPO_DIR/infrastructure/mcp-servers/setup-mcp.sh" \
    "$ECOSYSTEM_FIXTURE/infrastructure/mcp-servers/setup-mcp.sh"
printf '{"mcpServers":{"gitlab":{"token":"test-fixture-only"}}}\n' \
    > "$ECOSYSTEM_FIXTURE/.mcp.json"
printf '{"old":"configuration"}\n' > "$TARGET_DIR/.mcp.json"
chmod 644 "$TARGET_DIR/.mcp.json"

# Keep the smoke test hermetic: the installer may fall back to an existing MCP
# config when local GitLab is unavailable, so do not run the real MCP setup.
cat > "$FAKE_BIN/bash" <<'EOF'
#!/usr/bin/bash
if [[ "${1:-}" == */infrastructure/mcp-servers/setup-mcp.sh ]]; then
    exit 1
fi
exec /usr/bin/bash "$@"
EOF
chmod +x "$FAKE_BIN/bash"

OUTPUT="$TEST_ROOT/install-output.txt"
PATH="$FAKE_BIN:$PATH" \
HOME="$TEST_ROOT/home" \
CODEX_HOME="$TEST_CODEX_HOME" \
    /usr/bin/bash "$ECOSYSTEM_FIXTURE/scripts/install-to-project.sh" "$TARGET_DIR" > "$OUTPUT"

for screenshot_dir in e2e ui manual; do
    test -d "$TARGET_DIR/.okdev/test-results/screenshots/$screenshot_dir"
done

test ! -e "$TARGET_DIR/.okdev/test-results/screenshots/{e2e,ui,manual}"
test ! -e "$TARGET_DIR/.megadev"
test -d "$TARGET_DIR/.claude/skills"
test -d "$TEST_CODEX_HOME/skills"
test -f "$TEST_CODEX_HOME"/okdev-backups/*/kickoff/backup-sentinel
test "$(stat -c '%a' "$TARGET_DIR/.mcp.json")" = "600"
grep -Fq 'test-fixture-only' "$TARGET_DIR/.mcp.json"
grep -Fxq '.mcp.json' "$TARGET_DIR/.gitignore"
grep -Fq "OKDev installed" "$OUTPUT"
grep -Fq "$TEST_CODEX_HOME/okdev-backups" "$OUTPUT"

PATH="$FAKE_BIN:$PATH" \
HOME="$TEST_ROOT/home" \
CODEX_HOME="$TEST_CODEX_HOME" \
    /usr/bin/bash "$ECOSYSTEM_FIXTURE/scripts/install-to-project.sh" \
    "$FRESH_TARGET_DIR" > "$TEST_ROOT/fresh-install-output.txt"
test "$(stat -c '%a' "$FRESH_TARGET_DIR/.mcp.json")" = "600"

echo "Installer smoke test passed."
