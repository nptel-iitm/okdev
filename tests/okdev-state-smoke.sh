#!/usr/bin/env bash
set -uo pipefail

# Behaviour of the durable run state, which everything else rests on.
# Free to run: no model, no network.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$REPO_DIR/codex/lib/okdev-state"
FAILURES=0

ok()   { echo "  ok    $1"; }
fail() { echo "  FAIL  $1"; FAILURES=$((FAILURES + 1)); }

mkstate() { # dir workflow status
    mkdir -p "$1/.okdev"
    python3 -c "
import json, sys
json.dump({'schema': 1, 'workflow': sys.argv[2], 'status': sys.argv[3], 'phase': 'x',
           'phases_done': ['a'], 'loops': {'review:mr-1': {'rounds': 2, 'limit': 3}},
           'notes': {}, 'blocked': None, 'updated_at': '2026-07-29T10:00:00Z'},
          open(sys.argv[1] + '/.okdev/run-state.json', 'w'))" "$1" "$2" "$3"
}

field() { python3 -c "
import json, sys
print(json.load(open(sys.argv[1] + '/.okdev/run-state.json'))[sys.argv[2]])" "$1" "$2"; }

echo "starting a workflow"

# A project outlives any one workflow: kickoff finishing must not stop bugfix
# starting later. Returning the old state there is silent failure - the new run
# never begins, and a supervisor reading 'complete' exits having done nothing.
for prior in complete blocked; do
    T=$(mktemp -d); mkstate "$T" kickoff "$prior"
    python3 "$STATE" --root "$T" init --workflow bugfix --phase environment >/dev/null 2>&1
    [ "$(field "$T" workflow)" = "bugfix" ] && [ "$(field "$T" status)" = "running" ] \
        && ok "a $prior kickoff does not block a new bugfix" \
        || fail "a $prior kickoff blocked a new bugfix"
    ls "$T"/.okdev/history/*.json >/dev/null 2>&1 \
        && ok "  the finished $prior run was archived" \
        || fail "  the finished $prior run was lost"
    rm -rf "$T"
done

# Re-entering a run that is still going is the normal post-compaction case and
# must change nothing.
T=$(mktemp -d); mkstate "$T" kickoff running
python3 "$STATE" --root "$T" init --workflow kickoff --phase environment >/dev/null 2>&1
[ "$(field "$T" phase)" = "x" ] && ok "re-entering a running workflow preserves it" \
    || fail "re-entering a running workflow reset it"
python3 "$STATE" --root "$T" init --workflow bugfix --phase environment >/dev/null 2>&1
[ "$(field "$T" workflow)" = "kickoff" ] && ok "a running workflow is not replaced by another" \
    || fail "a running workflow was replaced"
rm -rf "$T"

echo "loop budgets"

T=$(mktemp -d)
python3 "$STATE" --root "$T" init --workflow kickoff --phase implement >/dev/null 2>&1
for i in 1 2 3; do python3 "$STATE" --root "$T" loop-bump review:mr-1 --limit 3 >/dev/null 2>&1; done
python3 "$STATE" --root "$T" loop-bump review:mr-1 --limit 3 >/dev/null 2>&1
[ $? -eq 3 ] && ok "a spent loop budget exits 3" || fail "a spent loop budget did not exit 3"
python3 "$STATE" --root "$T" loop-reset review:mr-1 >/dev/null 2>&1
python3 "$STATE" --root "$T" loop-bump review:mr-1 --limit 3 >/dev/null 2>&1
[ $? -eq 0 ] && ok "loop-reset restores the budget" || fail "loop-reset did not restore the budget"
rm -rf "$T"

echo
if [ "$FAILURES" -eq 0 ]; then
    echo "okdev-state smoke test: all checks passed"
else
    echo "okdev-state smoke test: $FAILURES check(s) failed"
    exit 1
fi
