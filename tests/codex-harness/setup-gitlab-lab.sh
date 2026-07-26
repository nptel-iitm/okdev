#!/usr/bin/env bash
set -euo pipefail

# Creates a throwaway GitLab project with a seeded application and real issues,
# so the skills that need GitLab can be tested against something real rather
# than only on the path where their infrastructure is missing.
#
#   ./setup-gitlab-lab.sh            # create okdev/notes-lab and file 3 issues
#   ./setup-gitlab-lab.sh --teardown # delete the project
#
# The seeded app has three defects planted in different layers, each with a
# matching issue: an API that accepts a note with no title, a query that
# ignores its owner filter so any account can read any other's notes, and a
# fixed-width stylesheet that makes the page unusable on a phone.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GITLAB_URL="${GITLAB_URL:-http://localhost:8929}"
API="$GITLAB_URL/api/v4"
TOKEN="$(cat "$REPO_DIR/infrastructure/gitlab/.gitlab-token")"
GROUP_PATH="okdev"
PROJECT_PATH="notes-lab"

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

# GitLab may be reachable only on the host (an SSH tunnel bound to 127.0.0.1 is
# common). Containers cannot see that, so republish it on the docker bridge
# gateway; run-codex.sh --gitlab then resolves gitlab.local to it.
gateway="$(docker network inspect bridge -f '{{(index .IPAM.Config 0).Gateway}}')"
if ! docker ps --filter name=okdev-gitlab-bridge --format '{{.Names}}' | grep -q .; then
    docker rm -f okdev-gitlab-bridge >/dev/null 2>&1 || true
    docker run -d --name okdev-gitlab-bridge --network host alpine/socat:1.8.0.3 \
        "TCP-LISTEN:8929,bind=$gateway,fork,reuseaddr" "TCP:127.0.0.1:8929" >/dev/null
    echo "published GitLab on $gateway:8929 for containers"
fi

GROUP_ID="$(api GET "/groups?search=$GROUP_PATH" \
    | python3 -c "import json,sys;g=[x for x in json.load(sys.stdin) if x['path']=='$GROUP_PATH'];print(g[0]['id'] if g else '')")"
if [ -z "$GROUP_ID" ]; then
    GROUP_ID="$(api POST "/groups" --data "name=$GROUP_PATH&path=$GROUP_PATH&visibility=private" \
        | python3 -c "import json,sys;print(json.load(sys.stdin)['id'])")"
    echo "created group $GROUP_PATH"
fi

if [ -n "$(project_id)" ]; then
    echo "project $GROUP_PATH/$PROJECT_PATH already exists; run --teardown first"
    exit 1
fi

PID="$(api POST "/projects" \
    --data "name=$PROJECT_PATH&path=$PROJECT_PATH&namespace_id=$GROUP_ID&visibility=private" \
    | python3 -c "import json,sys;print(json.load(sys.stdin)['id'])")"
echo "created project $GROUP_PATH/$PROJECT_PATH (id $PID)"

for label in bug feature test infrastructure documentation blocked; do
    api POST "/projects/$PID/labels" \
        --data-urlencode "name=$label" --data-urlencode "color=#428BCA" > /dev/null
done

SEED="$REPO_DIR/tests/codex-harness/fixtures/gitlab-notes-lab/seed"
if [ ! -d "$SEED" ]; then
    echo "ERROR: seed application missing at $SEED" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -r "$SEED"/. "$WORK/"
git -C "$WORK" init -q -b main
git -C "$WORK" add -A
git -C "$WORK" -c user.email=okdev@local -c user.name="OKDev Seed" \
    commit -qm "notes-lab: notes API, static frontend, SQLite store"
git -C "$WORK" remote add origin \
    "${GITLAB_URL/http:\/\//http://root:$TOKEN@}/$GROUP_PATH/$PROJECT_PATH.git"
git -C "$WORK" push -q origin main
echo "pushed the seed application"

ISSUES="$REPO_DIR/tests/codex-harness/fixtures/gitlab-notes-lab/issues"
for file in "$ISSUES"/*.md; do
    title="$(head -1 "$file" | sed 's/^# //')"
    api POST "/projects/$PID/issues" \
        --data-urlencode "title=$title" \
        --data-urlencode "description=$(tail -n +2 "$file")" \
        --data-urlencode "labels=bug" \
        | python3 -c "import json,sys;d=json.load(sys.stdin);print('  filed #%s %s' % (d['iid'], d['title']))"
done

echo
echo "lab ready: $GITLAB_URL/$GROUP_PATH/$PROJECT_PATH"
echo "run a skill against it with: run-codex.sh --gitlab ..."
