#!/usr/bin/env bash
set -euo pipefail

# Smoke test for scripts/install-to-project.sh across all three harness modes.
#
# The property that matters most: a Codex install must land the Codex skill
# tree and the run-state helper, and must not land the Claude tree. Installing
# the wrong tree for the harness is the defect this split exists to fix, and it
# is silent at install time.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d /tmp/okdev-installer-test-XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT

FAKE_BIN="$TEST_ROOT/bin"
ECOSYSTEM="$TEST_ROOT/ecosystem"
mkdir -p "$FAKE_BIN" "$ECOSYSTEM/scripts" "$ECOSYSTEM/infrastructure/mcp-servers"

# Dereference the .claude symlinks so the fixture does not depend on how the
# working checkout is laid out.
cp -rL "$REPO_DIR/claude" "$ECOSYSTEM/claude"
cp -rL "$REPO_DIR/codex" "$ECOSYSTEM/codex"
cp "$REPO_DIR/CLAUDE.md" "$ECOSYSTEM/CLAUDE.md"
cp "$REPO_DIR/scripts/install-to-project.sh" "$ECOSYSTEM/scripts/install-to-project.sh"
cp "$REPO_DIR/infrastructure/mcp-servers/setup-mcp.sh" \
    "$ECOSYSTEM/infrastructure/mcp-servers/setup-mcp.sh"
printf '{"mcpServers":{"gitlab":{"token":"test-fixture-only"}}}\n' > "$ECOSYSTEM/.mcp.json"

# Keep the test hermetic: never run the real MCP setup, which needs GitLab.
cat > "$FAKE_BIN/bash" <<'EOF'
#!/usr/bin/bash
if [[ "${1:-}" == */infrastructure/mcp-servers/setup-mcp.sh ]]; then
    exit 1
fi
exec /usr/bin/bash "$@"
EOF
chmod +x "$FAKE_BIN/bash"

FAILURES=0
check() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  ok    $label"
    else
        echo "  FAIL  $label"
        FAILURES=$((FAILURES + 1))
    fi
}

run_install() {
    local target="$1" harness="$2" codex_home="$3"
    mkdir -p "$target" "$codex_home"
    PATH="$FAKE_BIN:$PATH" HOME="$TEST_ROOT/home" CODEX_HOME="$codex_home" \
        /usr/bin/bash "$ECOSYSTEM/scripts/install-to-project.sh" \
        "$target" --harness "$harness" > "$target/.install.log" 2>&1
}

echo "claude-only install"
T="$TEST_ROOT/t-claude"; C="$TEST_ROOT/ch-claude"
run_install "$T" claude "$C"
check "installs the Claude skill tree"     test -f "$T/.claude/skills/kickoff/SKILL.md"
check "installs CLAUDE.md"                 test -f "$T/CLAUDE.md"
check "installs settings.json"             test -f "$T/.claude/settings.json"
check "does not write AGENTS.md"           test ! -f "$T/AGENTS.md"
check "does not install the state helper"  test ! -f "$T/.okdev/bin/okdev-state"
check "does not install the supervisor"    test ! -f "$T/.okdev/bin/okdev-supervise"
check "leaves CODEX_HOME skills alone"     test ! -d "$C/skills/kickoff"
check "creates the test-results tree"      test -d "$T/.okdev/test-results/screenshots/ui"
check "secures .mcp.json"                  test "$(stat -c '%a' "$T/.mcp.json")" = "600"
check "ignores .mcp.json"                  grep -Fxq '.mcp.json' "$T/.gitignore"

echo "codex-only install"
T="$TEST_ROOT/t-codex"; C="$TEST_ROOT/ch-codex"
run_install "$T" codex "$C"
check "installs the Codex skill tree"      test -f "$C/skills/kickoff/SKILL.md"
check "installs AGENTS.md"                 test -f "$T/AGENTS.md"
check "installs the state helper"          test -x "$T/.okdev/bin/okdev-state"
check "does NOT install the Claude tree"   test ! -d "$T/.claude/skills"
check "does not write CLAUDE.md"           test ! -f "$T/CLAUDE.md"
check "installed tree is the Codex one"    grep -q "okdev-state" "$C/skills/kickoff/SKILL.md"
check "state helper runs"                  python3 "$T/.okdev/bin/okdev-state" --root "$T" init --workflow smoke
check "installs the supervisor"            test -x "$T/.okdev/bin/okdev-supervise"
check "supervisor parses"                  bash -n "$T/.okdev/bin/okdev-supervise"
check "supervisor requires a project"      bash -c '! bash "$1" --skill kickoff' _ "$T/.okdev/bin/okdev-supervise"

echo "both install"
T="$TEST_ROOT/t-both"; C="$TEST_ROOT/ch-both"
run_install "$T" both "$C"
check "installs the Claude skill tree"     test -f "$T/.claude/skills/kickoff/SKILL.md"
check "installs the Codex skill tree"      test -f "$C/skills/kickoff/SKILL.md"
check "installs CLAUDE.md"                 test -f "$T/CLAUDE.md"
check "installs AGENTS.md"                 test -f "$T/AGENTS.md"
check "installs the state helper"          test -x "$T/.okdev/bin/okdev-state"

echo "existing Codex skills are backed up"
T="$TEST_ROOT/t-backup"; C="$TEST_ROOT/ch-backup"
mkdir -p "$C/skills/kickoff"
printf 'pre-existing\n' > "$C/skills/kickoff/sentinel"
run_install "$T" codex "$C"
check "the replaced skill was backed up" \
    /usr/bin/bash -c "compgen -G '$C/okdev-backups/*/skills/kickoff/sentinel'"
check "the replaced skill is now the new one" test -f "$C/skills/kickoff/SKILL.md"

echo "argument handling"
check "rejects an unknown harness" \
    /usr/bin/bash -c "! /usr/bin/bash '$ECOSYSTEM/scripts/install-to-project.sh' '$TEST_ROOT' --harness nonsense"
check "rejects a missing target" \
    /usr/bin/bash -c "! /usr/bin/bash '$ECOSYSTEM/scripts/install-to-project.sh' /nope/nowhere --harness claude"
check "refuses to guess without a terminal" \
    /usr/bin/bash -c "! /usr/bin/bash '$ECOSYSTEM/scripts/install-to-project.sh' '$TEST_ROOT/t-claude' < /dev/null"

echo
if [ "$FAILURES" -eq 0 ]; then
    echo "install smoke test: all checks passed"
else
    echo "install smoke test: $FAILURES check(s) failed"
    exit 1
fi
