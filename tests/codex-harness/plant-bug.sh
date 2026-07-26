#!/usr/bin/env bash
set -euo pipefail

# Plants a regression on a project's main branch and files the issue a user
# would file about it.
#
#   ./plant-bug.sh <group/project> <patch-file> <issue-file> "<commit subject>"
#
# The commit goes straight to main, the way a real regression arrives. The
# issue describes symptoms only - it must not name a file, a function or a
# cause, or the investigation being tested is handed its own answer.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GITLAB_URL="${GITLAB_URL:-http://localhost:8929}"
API="$GITLAB_URL/api/v4"
TOKEN="$(cat "$REPO_DIR/infrastructure/gitlab/.gitlab-token")"

PROJECT="${1:?usage: plant-bug.sh <group/project> <patch> <issue.md> <subject>}"
PATCH="${2:?patch file required}"
ISSUE="${3:?issue markdown required}"
SUBJECT="${4:-Tidy up booking helpers}"

PATCH="$(cd "$(dirname "$PATCH")" && pwd)/$(basename "$PATCH")"
ISSUE="$(cd "$(dirname "$ISSUE")" && pwd)/$(basename "$ISSUE")"

api() {
    local method="$1" path="$2"; shift 2
    curl -sS --request "$method" --header "PRIVATE-TOKEN: $TOKEN" "$API$path" "$@"
}

PID="$(api GET "/projects/$(printf '%s' "$PROJECT" | sed 's|/|%2F|')" \
    | python3 -c "import json,sys;print(json.load(sys.stdin)['id'])")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git clone -q "${GITLAB_URL/http:\/\//http://root:$TOKEN@}/$PROJECT.git" "$WORK/clone"
cd "$WORK/clone"
echo "main is at $(git log --oneline -1)"

git apply --verbose "$PATCH"
git -c user.email=okdev@local -c user.name="OKDev" commit -qam "$SUBJECT"
git push -q origin main
echo "planted: $(git log --oneline -1)"

TITLE="$(head -1 "$ISSUE" | sed 's/^# //')"
api POST "/projects/$PID/issues" \
    --data-urlencode "title=$TITLE" \
    --data-urlencode "description=$(tail -n +2 "$ISSUE")" \
    --data-urlencode "labels=bug" \
    | python3 -c "import json,sys;d=json.load(sys.stdin);print('filed #%s %s' % (d['iid'], d['title']))"
