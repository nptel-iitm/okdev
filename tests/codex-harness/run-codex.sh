#!/usr/bin/env bash
# Runs one OKDev skill under Codex inside an isolated Docker container and
# records everything needed to score it.
#
# Each run gets a private CODEX_HOME (so sessions, state and skills never leak
# between runs) and a private copy of the fixture repo. Nothing touches the
# host's ~/.codex except a read of auth.json.
#
# Usage:
#   run-codex.sh --run-id <id> --prompt-file <path> [options]
#
# Options:
#   --skills <dir>     skill tree to install (default: repo codex/skills)
#   --fixture <dir>    fixture repo copied into the workspace (default: empty repo)
#   --model <slug>     default gpt-5.6-terra
#   --effort <level>   low|medium|high|xhigh|max   (default medium)
#   --timeout <sec>    wall-clock cap for the container (default 900)
#   --no-network       cut the container off from the network (default: on;
#                      Codex needs it to reach the API at all)
#
# Writes to $OKDEV_LAB/runs/<run-id>/:
#   events.jsonl   raw codex event stream
#   last-message   the agent's final message
#   result.json    usage, timing, budget delta, exit status
#   work/          the workspace as the agent left it
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAB="${OKDEV_LAB:-/run/media/rishav/data/okdev-codex-lab}"
IMAGE="${OKDEV_CODEX_IMAGE:-okdev-codex-test:0.145.0}"

RUN_ID=""; PROMPT_FILE=""; FIXTURE=""
SKILLS="$REPO_DIR/codex/skills"
MODEL="gpt-5.6-terra"; EFFORT="medium"; TIMEOUT=900; NETWORK="bridge"

while [ $# -gt 0 ]; do
    case "$1" in
        --run-id)      RUN_ID="$2"; shift 2 ;;
        --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
        --skills)      SKILLS="$2"; shift 2 ;;
        --fixture)     FIXTURE="$2"; shift 2 ;;
        --model)       MODEL="$2"; shift 2 ;;
        --effort)      EFFORT="$2"; shift 2 ;;
        --timeout)     TIMEOUT="$2"; shift 2 ;;
        --no-network)  NETWORK="none"; shift ;;
        *) echo "run-codex: unknown option $1" >&2; exit 2 ;;
    esac
done

[ -n "$RUN_ID" ]      || { echo "run-codex: --run-id is required" >&2; exit 2; }
[ -f "$PROMPT_FILE" ] || { echo "run-codex: --prompt-file not found: $PROMPT_FILE" >&2; exit 2; }

# Refuse to spend budget we do not have. This is the only gate that matters.
bash "$REPO_DIR/tests/codex-harness/budget.sh" check

RUN_DIR="$LAB/runs/$RUN_ID"
if [ -e "$RUN_DIR" ]; then
    echo "run-codex: run id '$RUN_ID' already exists at $RUN_DIR" >&2
    exit 2
fi
mkdir -p "$RUN_DIR/codexhome/skills" "$RUN_DIR/work" "$RUN_DIR/agenthome"

# Private CODEX_HOME: auth is copied, never mounted, so a token refresh inside
# the container cannot corrupt the host's credentials.
cp "${CODEX_HOME:-$HOME/.codex}/auth.json" "$RUN_DIR/codexhome/auth.json"
chmod 600 "$RUN_DIR/codexhome/auth.json"

cat > "$RUN_DIR/codexhome/config.toml" <<EOF
model = "$MODEL"
model_reasoning_effort = "$EFFORT"

[projects."/work"]
trust_level = "trusted"
EOF

if [ -d "$SKILLS" ]; then
    cp -r "$SKILLS"/* "$RUN_DIR/codexhome/skills/" 2>/dev/null || true
fi

if [ -n "$FIXTURE" ]; then
    [ -d "$FIXTURE" ] || { echo "run-codex: fixture not found: $FIXTURE" >&2; exit 2; }
    cp -r "$FIXTURE"/. "$RUN_DIR/work/"
fi

# Install the OKDev runtime the skills expect: the durable state helper they
# call, and the shared operating rules Codex loads from AGENTS.md.
mkdir -p "$RUN_DIR/work/.okdev/bin"
cp "$REPO_DIR/codex/lib/okdev-state" "$RUN_DIR/work/.okdev/bin/okdev-state"
chmod +x "$RUN_DIR/work/.okdev/bin/okdev-state"
if [ ! -f "$RUN_DIR/work/AGENTS.md" ]; then
    cp "$REPO_DIR/codex/AGENTS.md" "$RUN_DIR/work/AGENTS.md"
fi

# Every fixture is a git repo so the agent can branch and commit, and so the
# scorer can diff what actually changed.
if [ ! -d "$RUN_DIR/work/.git" ]; then
    git -C "$RUN_DIR/work" init -q
    git -C "$RUN_DIR/work" add -A
    git -C "$RUN_DIR/work" -c user.email=harness@okdev.local -c user.name=harness \
        commit -qm "fixture baseline" --allow-empty
fi
BASE_SHA=$(git -C "$RUN_DIR/work" rev-parse HEAD)

cp "$PROMPT_FILE" "$RUN_DIR/prompt.txt"

USED_BEFORE=$(bash "$REPO_DIR/tests/codex-harness/budget.sh" used)
STARTED=$(date +%s)
set +e
timeout "$TIMEOUT" docker run --rm \
    --user "$(id -u):$(id -g)" \
    --network "$NETWORK" \
    -v "$RUN_DIR/codexhome:/codexhome" \
    -v "$RUN_DIR/work:/work" \
    -v "$RUN_DIR/agenthome:/agenthome" \
    -e CODEX_HOME=/codexhome \
    -e HOME=/agenthome \
    "$IMAGE" \
    codex exec --json \
        -m "$MODEL" \
        -c model_reasoning_effort="$EFFORT" \
        -s workspace-write \
        --dangerously-bypass-approvals-and-sandbox \
        -C /work \
        --output-last-message /work/.okdev-last-message \
        - < "$RUN_DIR/prompt.txt" \
    > "$RUN_DIR/events.jsonl" 2> "$RUN_DIR/stderr.log"
EXIT_CODE=$?
set -e
ENDED=$(date +%s)
USED_AFTER=$(bash "$REPO_DIR/tests/codex-harness/budget.sh" used)

mv "$RUN_DIR/work/.okdev-last-message" "$RUN_DIR/last-message" 2>/dev/null || \
    : > "$RUN_DIR/last-message"

RUN_ID="$RUN_ID" MODEL="$MODEL" EFFORT="$EFFORT" EXIT_CODE="$EXIT_CODE" \
STARTED="$STARTED" ENDED="$ENDED" TIMEOUT="$TIMEOUT" \
USED_BEFORE="$USED_BEFORE" USED_AFTER="$USED_AFTER" BASE_SHA="$BASE_SHA" \
python3 - "$RUN_DIR" <<'PY'
import json, os, sys

run_dir = sys.argv[1]

# Sum usage across every turn; a skill run is often several turns.
totals = {}
turns = 0
commands = 0
for line in open(os.path.join(run_dir, "events.jsonl"), errors="replace"):
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        ev = json.loads(line)
    except json.JSONDecodeError:
        continue
    if ev.get("type") == "turn.completed":
        turns += 1
        for k, v in (ev.get("usage") or {}).items():
            totals[k] = totals.get(k, 0) + v
    item = ev.get("item") or {}
    if ev.get("type") == "item.completed" and item.get("type") == "command_execution":
        commands += 1

started, ended = int(os.environ["STARTED"]), int(os.environ["ENDED"])
exit_code = int(os.environ["EXIT_CODE"])
result = {
    "run_id": os.environ["RUN_ID"],
    "model": os.environ["MODEL"],
    "effort": os.environ["EFFORT"],
    "exit_code": exit_code,
    "timed_out": exit_code == 124,
    "duration_seconds": ended - started,
    "timeout_seconds": int(os.environ["TIMEOUT"]),
    "turns": turns,
    "commands_run": commands,
    "usage": totals,
    "budget_percent_before": int(os.environ["USED_BEFORE"]),
    "budget_percent_after": int(os.environ["USED_AFTER"]),
    "base_sha": os.environ["BASE_SHA"],
}
with open(os.path.join(run_dir, "result.json"), "w") as fh:
    json.dump(result, fh, indent=2)
print(json.dumps(result, indent=2))
PY

echo "run-codex: artifacts in $RUN_DIR"
exit 0
