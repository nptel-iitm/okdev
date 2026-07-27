#!/usr/bin/env bash
set -euo pipefail

# Creates an EMPTY GitLab project for a greenfield $kickoff run, plus the
# workspace the agent starts from: a brief, a .mcp.json the environment phase
# can authenticate with, and an origin remote that can already push.
#
#   ./setup-greenfield-lab.sh <run-workspace-dir>   # create okdev/labslots
#   ./setup-greenfield-lab.sh --teardown
#
# Unlike setup-gitlab-lab.sh there is no seed application. The point is to test
# whether kickoff can build one, so the repo starts with nothing but a brief.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GITLAB_URL="${GITLAB_URL:-http://localhost:8929}"
API="$GITLAB_URL/api/v4"
TOKEN="$(cat "$REPO_DIR/infrastructure/gitlab/.gitlab-token")"
GROUP_PATH="okdev"
PROJECT_PATH="${OKDEV_GREENFIELD_PROJECT:-labslots}"

api() {
    local method="$1" path="$2"; shift 2
    curl -sS --request "$method" --header "PRIVATE-TOKEN: $TOKEN" "$API$path" "$@"
}

project_id() {
    api GET "/projects/$(printf '%s' "$GROUP_PATH/$PROJECT_PATH" | sed 's|/|%2F|')" \
        | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('id',''))" 2>/dev/null || true
}

if [ "${1:-}" = "--teardown" ]; then
    PID="$(project_id)"
    if [ -n "$PID" ]; then
        api DELETE "/projects/$PID" > /dev/null
        echo "deleted $GROUP_PATH/$PROJECT_PATH (id $PID)"
    else
        echo "nothing to delete"
    fi
    exit 0
fi

WORKSPACE="${1:-}"
[ -n "$WORKSPACE" ] || { echo "usage: setup-greenfield-lab.sh <workspace-dir>" >&2; exit 2; }

# Containers cannot see a GitLab bound to 127.0.0.1 (an SSH tunnel is the
# common case here), so republish it on the docker bridge gateway.
gateway="$(docker network inspect bridge -f '{{(index .IPAM.Config 0).Gateway}}')"
if ! docker ps --filter name=okdev-gitlab-bridge --format '{{.Names}}' | grep -q .; then
    docker rm -f okdev-gitlab-bridge >/dev/null 2>&1 || true
    docker run -d --name okdev-gitlab-bridge --network host alpine/socat:1.8.0.3 \
        "TCP-LISTEN:8929,bind=$gateway,fork,reuseaddr" "TCP:127.0.0.1:8929" >/dev/null
    echo "published GitLab on $gateway:8929 for containers"
fi

GROUP_ID="$(api GET "/groups?search=$GROUP_PATH" \
    | python3 -c "import json,sys;g=[x for x in json.load(sys.stdin) if x['path']=='$GROUP_PATH'];print(g[0]['id'] if g else '')")"
[ -n "$GROUP_ID" ] || { echo "group $GROUP_PATH missing" >&2; exit 1; }

if [ -n "$(project_id)" ]; then
    echo "project $GROUP_PATH/$PROJECT_PATH already exists; run --teardown first" >&2
    exit 1
fi

PID="$(api POST "/projects" \
    --data "name=$PROJECT_PATH&path=$PROJECT_PATH&namespace_id=$GROUP_ID&visibility=private&initialize_with_readme=false" \
    | python3 -c "import json,sys;print(json.load(sys.stdin)['id'])")"
echo "created empty project $GROUP_PATH/$PROJECT_PATH (id $PID)"

for label in bug feature test infrastructure documentation blocked; do
    api POST "/projects/$PID/labels" \
        --data-urlencode "name=$label" --data-urlencode "color=#428BCA" > /dev/null
done
echo "created labels"

# The workspace the agent wakes up in: the brief, a token it can authenticate
# with, and a remote it can push to.
mkdir -p "$WORKSPACE"
BRIEF="${OKDEV_GREENFIELD_BRIEF:-$REPO_DIR/tests/codex-harness/fixtures/greenfield-labslots/repo/BRIEF.md}"
[ -f "$BRIEF" ] || { echo "brief not found: $BRIEF" >&2; exit 2; }
cp "$BRIEF" "$WORKSPACE/BRIEF.md"

cat > "$WORKSPACE/.mcp.json" <<JSON
{
  "gitlab": {
    "url": "http://gitlab.local:8929",
    "project": "$GROUP_PATH/$PROJECT_PATH",
    "token_env": "GITLAB_TOKEN"
  }
}
JSON

git -C "$WORKSPACE" init -q -b main
git -C "$WORKSPACE" remote add origin \
    "http://root:$TOKEN@gitlab.local:8929/$GROUP_PATH/$PROJECT_PATH.git"

echo "workspace ready at $WORKSPACE (project id $PID)"
