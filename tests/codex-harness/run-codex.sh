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
#   --image <tag>      container image; use okdev-codex-browser:0.145.0 for
#                      fixtures that need a real browser
#   --runtime <name>   codex (okdev-state + AGENTS.md, default), claude
#                      (CLAUDE.md only - use for control runs), or none
#   --compact-at <n>   force auto-compaction once the context passes n tokens.
#                      The loop failures reported in issue #15 only appear once
#                      a run has been compacted, so a test for them has to make
#                      compaction happen rather than wait for a huge run.
#   --reuse-work <dir> start from an existing workspace instead of a fixture. A
#                      fresh session over a used workspace is compaction taken
#                      to its limit: no conversational memory at all, so only
#                      state written to disk can survive.
#   --gitlab           make the host's GitLab reachable from inside the
#                      container as gitlab.local:8929, and pass the API token
#                      in as GITLAB_TOKEN
#   --docker           mount the host Docker socket, so a skill can run its
#                      tooling in a container as its instructions require.
#                      Also mounts the workspace at its host path, because
#                      containers the agent starts are siblings whose bind
#                      mounts resolve against the host filesystem, and adds
#                      host.docker.internal so the agent can reach ports its
#                      own stack publishes.
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
MODEL="gpt-5.6-terra"; EFFORT="medium"; TIMEOUT=900; NETWORK="bridge"; RUNTIME="codex"; COMPACT_AT=""; REUSE_WORK=""; GITLAB=0; DOCKER_SOCK=0

while [ $# -gt 0 ]; do
    case "$1" in
        --run-id)      RUN_ID="$2"; shift 2 ;;
        --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
        --skills)      SKILLS="$2"; shift 2 ;;
        --fixture)     FIXTURE="$2"; shift 2 ;;
        --model)       MODEL="$2"; shift 2 ;;
        --effort)      EFFORT="$2"; shift 2 ;;
        --timeout)     TIMEOUT="$2"; shift 2 ;;
        --image)       IMAGE="$2"; shift 2 ;;
        --runtime)     RUNTIME="$2"; shift 2 ;;
        --compact-at)  COMPACT_AT="$2"; shift 2 ;;
        --reuse-work)  REUSE_WORK="$2"; shift 2 ;;
        --gitlab)      GITLAB=1; shift ;;
        --docker)      DOCKER_SOCK=1; shift ;;
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

# Where the workspace appears inside the container. Normally /work, which keeps
# runs identical regardless of where the lab lives. With --docker it must be the
# host path instead: containers the agent starts are siblings on the host
# daemon, so their bind mounts resolve against the host filesystem. Mounting at
# /work would make `docker compose` silently mount an empty directory - the
# service starts, the code is not there, and the failure looks like a bug in
# the application rather than in the harness.
if [ "$DOCKER_SOCK" = "1" ]; then
    WORK_PATH="$RUN_DIR/work"
else
    WORK_PATH="/work"
fi

# Private CODEX_HOME: auth is copied, never mounted, so a token refresh inside
# the container cannot corrupt the host's credentials.
cp "${CODEX_HOME:-$HOME/.codex}/auth.json" "$RUN_DIR/codexhome/auth.json"
chmod 600 "$RUN_DIR/codexhome/auth.json"

cat > "$RUN_DIR/codexhome/config.toml" <<EOF
model = "$MODEL"
model_reasoning_effort = "$EFFORT"

[projects."$WORK_PATH"]
trust_level = "trusted"
EOF

if [ -n "$COMPACT_AT" ]; then
    echo "model_auto_compact_token_limit = $COMPACT_AT" >> "$RUN_DIR/codexhome/config.toml"
fi

if [ -d "$SKILLS" ]; then
    cp -r "$SKILLS"/* "$RUN_DIR/codexhome/skills/" 2>/dev/null || true
fi

if [ -n "$REUSE_WORK" ]; then
    [ -d "$REUSE_WORK" ] || { echo "run-codex: workspace not found: $REUSE_WORK" >&2; exit 2; }
    cp -r "$REUSE_WORK"/. "$RUN_DIR/work/"
elif [ -n "$FIXTURE" ]; then
    [ -d "$FIXTURE" ] || { echo "run-codex: fixture not found: $FIXTURE" >&2; exit 2; }
    cp -r "$FIXTURE"/. "$RUN_DIR/work/"
fi

# Install the runtime the chosen harness expects. Getting this wrong silently
# ruins a control run: dropping codex/AGENTS.md into a workspace hands the old
# Claude skills the new operating rules, and they then appear to behave
# correctly for reasons that have nothing to do with the skill under test.
case "$RUNTIME" in
    codex)
        mkdir -p "$RUN_DIR/work/.okdev/bin"
        cp "$REPO_DIR/codex/lib/okdev-state" "$RUN_DIR/work/.okdev/bin/okdev-state"
        chmod +x "$RUN_DIR/work/.okdev/bin/okdev-state"
        [ -f "$RUN_DIR/work/AGENTS.md" ] || cp "$REPO_DIR/codex/AGENTS.md" "$RUN_DIR/work/AGENTS.md"
        ;;
    claude)
        # What the previous installer produced for a Codex user: the Claude
        # skill tree plus CLAUDE.md, and no durable state helper.
        [ -f "$RUN_DIR/work/CLAUDE.md" ] || cp "$REPO_DIR/CLAUDE.md" "$RUN_DIR/work/CLAUDE.md"
        ;;
    none) ;;
    *) echo "run-codex: unknown runtime '$RUNTIME'" >&2; exit 2 ;;
esac

# Every fixture is a git repo so the agent can branch and commit, and so the
# scorer can diff what actually changed.
if [ ! -d "$RUN_DIR/work/.git" ]; then
    git -C "$RUN_DIR/work" init -q
    git -C "$RUN_DIR/work" add -A
    git -C "$RUN_DIR/work" -c user.email=harness@okdev.local -c user.name=harness \
        commit -qm "fixture baseline" --allow-empty
fi
# A fixture may arrive with a repo that has no commits yet (a greenfield run
# starts from an empty remote), so an unborn HEAD is not an error here.
BASE_SHA=$(git -C "$RUN_DIR/work" rev-parse HEAD 2>/dev/null || echo "unborn")

cp "$PROMPT_FILE" "$RUN_DIR/prompt.txt"

USED_BEFORE=$(bash "$REPO_DIR/tests/codex-harness/budget.sh" used)
STARTED=$(date +%s)
set +e
# GitLab runs on the host, so the container reaches it through the gateway
# rather than by joining the host network - that keeps any port the agent
# binds inside the container.
DOCKER_EXTRA=()
if [ "$DOCKER_SOCK" = "1" ]; then
    DOCKER_EXTRA+=(-v /var/run/docker.sock:/var/run/docker.sock)
    DOCKER_EXTRA+=(--group-add "$(stat -c '%g' /var/run/docker.sock)")
    # Ports a sibling container publishes land on the host, not in here, so
    # give the agent a name that resolves to the host to reach its own stack.
    DOCKER_EXTRA+=(--add-host "host.docker.internal:host-gateway")
fi

if [ "$GITLAB" = "1" ]; then
    DOCKER_EXTRA+=(--add-host "gitlab.local:host-gateway")
    DOCKER_EXTRA+=(-e "GITLAB_TOKEN=$(cat "$REPO_DIR/infrastructure/gitlab/.gitlab-token")")
    DOCKER_EXTRA+=(-e "GITLAB_URL=http://gitlab.local:8929")
fi

# Budget kill-switch. The pre-flight check above only guards the moment a run
# starts; a long run can spend the rest of the window after it. The first time
# this harness was used for a full kickoff, the ceiling was enforced by a
# watchdog in the calling shell - the session died, the watchdog died with it,
# the container carried on, and the run overshot its ceiling by 13 points.
#
# So the watchdog is detached with setsid: it outlives this script, this shell
# and the session, and it kills the run by container name. It exits on its own
# once the container is gone, so it cannot leak.
CONTAINER_NAME="okdev-run-$RUN_ID"
CEILING="${OKDEV_BUDGET_CEILING:-12}"
setsid bash -c '
    name="$1"; ceiling="$2"; budget="$3"
    sleep 30
    while docker inspect "$name" >/dev/null 2>&1; do
        used=$(bash "$budget" used 2>/dev/null || echo 0)
        case "$used" in ""|*[!0-9]*) used=0 ;; esac
        if [ "$used" -ge "$ceiling" ]; then
            echo "budget watchdog: ${used}% >= ${ceiling}% - killing $name" >&2
            docker kill "$name" >/dev/null 2>&1
            exit 3
        fi
        sleep 45
    done
' _ "$CONTAINER_NAME" "$CEILING" "$REPO_DIR/tests/codex-harness/budget.sh" \
    > "$RUN_DIR/watchdog.log" 2>&1 < /dev/null &
WATCHDOG_PID=$!

timeout "$TIMEOUT" docker run --rm -i \
    --name "$CONTAINER_NAME" \
    --user "$(id -u):$(id -g)" \
    --network "$NETWORK" \
    "${DOCKER_EXTRA[@]+"${DOCKER_EXTRA[@]}"}" \
    -v "$RUN_DIR/codexhome:/codexhome" \
    -v "$RUN_DIR/work:$WORK_PATH" \
    -v "$RUN_DIR/agenthome:/agenthome" \
    -e CODEX_HOME=/codexhome \
    -e HOME=/agenthome \
    -e "OKDEV_WORKSPACE=$WORK_PATH" \
    "$IMAGE" \
    codex exec --json \
        -m "$MODEL" \
        -c model_reasoning_effort="$EFFORT" \
        -s workspace-write \
        --dangerously-bypass-approvals-and-sandbox \
        -C "$WORK_PATH" \
        --output-last-message "$WORK_PATH/.okdev-last-message" \
        - < "$RUN_DIR/prompt.txt" \
    > "$RUN_DIR/events.jsonl" 2> "$RUN_DIR/stderr.log"
EXIT_CODE=$?
set -e
ENDED=$(date +%s)

# The watchdog exits by itself when the container disappears, but do not make
# the next run wait on that poll interval.
kill "$WATCHDOG_PID" 2>/dev/null || true
KILLED_BY_BUDGET=0
if grep -q "budget watchdog" "$RUN_DIR/watchdog.log" 2>/dev/null; then
    KILLED_BY_BUDGET=1
    echo "run-codex: RUN STOPPED BY BUDGET WATCHDOG" >&2
    cat "$RUN_DIR/watchdog.log" >&2
fi

USED_AFTER=$(bash "$REPO_DIR/tests/codex-harness/budget.sh" used)

mv "$RUN_DIR/work/.okdev-last-message" "$RUN_DIR/last-message" 2>/dev/null || \
    : > "$RUN_DIR/last-message"

RUN_ID="$RUN_ID" MODEL="$MODEL" EFFORT="$EFFORT" EXIT_CODE="$EXIT_CODE" \
STARTED="$STARTED" ENDED="$ENDED" TIMEOUT="$TIMEOUT" \
KILLED_BY_BUDGET="$KILLED_BY_BUDGET" CEILING="$CEILING" \
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

# Sub-agent activity never appears in the --json stream: a parent waiting on a
# productive worker emits the same `wait` event as a parent waiting on nothing.
# Each thread does get its own rollout file, so counting them is the only
# reliable way to tell delegation from a stall. Anything above 1 is a sub-agent.
sessions = os.path.join(run_dir, "codexhome", "sessions")
threads = sum(
    1
    for root, _dirs, files in os.walk(sessions)
    for f in files
    if f.startswith("rollout-") and f.endswith(".jsonl")
)

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
    "threads": threads,
    "subagents": max(0, threads - 1),
    "killed_by_budget": os.environ.get("KILLED_BY_BUDGET") == "1",
    "budget_ceiling": int(os.environ.get("CEILING", "0")),
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
