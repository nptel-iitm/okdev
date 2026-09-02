#!/usr/bin/env bash
set -euo pipefail

# Brings up a GitLab project's main branch from a fresh clone and runs a probe
# script against it. Nothing here reads the agent's own report - the point is to
# check the claim independently, from the state a new colleague would get.
#
#   ./verify-from-main.sh <group/project> <probe.sh> [port]
#
# The probe receives BASE_URL in its environment and should exit non-zero on
# any failed expectation. The stack is torn down afterwards either way.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GITLAB_URL="${GITLAB_URL:-http://localhost:8929}"
TOKEN="$(cat "$REPO_DIR/infrastructure/gitlab/.gitlab-token")"

PROJECT="${1:?usage: verify-from-main.sh <group/project> <probe.sh> [port]}"
PROBE="${2:?usage: verify-from-main.sh <group/project> <probe.sh> [port]}"
PORT="${3:-18150}"

[ -f "$PROBE" ] || { echo "probe not found: $PROBE" >&2; exit 2; }
PROBE="$(cd "$(dirname "$PROBE")" && pwd)/$(basename "$PROBE")"

WORK="$(mktemp -d "${OKDEV_LAB:-/run/media/rishav/data/okdev-codex-lab}/verify-XXXXXX")"
cleanup() {
    if [ -f "$WORK/clone/docker-compose.yml" ]; then
        docker compose -f "$WORK/clone/docker-compose.yml" down -v --remove-orphans >/dev/null 2>&1 || true
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT

echo "cloning $PROJECT main into $WORK/clone"
git clone -q --depth 1 "${GITLAB_URL/http:\/\//http://root:$TOKEN@}/$PROJECT.git" "$WORK/clone"
echo "HEAD: $(git -C "$WORK/clone" log --oneline -1)"

cd "$WORK/clone"
[ -f docker-compose.yml ] || { echo "FAIL: no docker-compose.yml on main" >&2; exit 1; }
[ -f .env ] || { [ -f .env.example ] && cp .env.example .env; } || true

echo "bringing the stack up"
docker compose up -d --quiet-pull 2>&1 | tail -5

BASE_URL="http://localhost:$PORT"
echo "waiting for $BASE_URL"
for i in $(seq 1 90); do
    if curl -sS -m 3 -o /dev/null "$BASE_URL/" 2>/dev/null; then break; fi
    printf 'waiting %s/90\r' "$i"
    sleep 2
done
echo

if ! curl -sS -m 5 -o /dev/null "$BASE_URL/"; then
    echo "FAIL: stack did not answer on $BASE_URL" >&2
    docker compose logs --tail 40 2>&1 | tail -40
    exit 1
fi

echo "running probe: $PROBE"
BASE_URL="$BASE_URL" bash -o pipefail "$PROBE"
STATUS=$?
echo "probe exit: $STATUS"
exit $STATUS
