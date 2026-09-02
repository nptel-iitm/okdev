#!/usr/bin/env bash
# Reads the ChatGPT-plan Codex rate-limit window and enforces a hard ceiling.
#
#   budget.sh used            -> prints the weekly used_percent as an integer
#   budget.sh json            -> prints the full /wham/usage payload
#   budget.sh check           -> exits 1 if used_percent >= OKDEV_BUDGET_CEILING
#
# The ceiling is an ABSOLUTE percentage of the weekly window, not a delta.
# Set OKDEV_BUDGET_CEILING before running the suite; the harness refuses to
# fire a Codex turn once the ceiling is reached.
set -euo pipefail

CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
AUTH_FILE="$CODEX_HOME_DIR/auth.json"
CEILING="${OKDEV_BUDGET_CEILING:-12}"

if [ ! -f "$AUTH_FILE" ]; then
    echo "budget: no auth.json at $AUTH_FILE" >&2
    exit 2
fi

fetch_usage() {
    python3 - "$AUTH_FILE" <<'PY'
import base64, json, sys, urllib.request

auth = json.load(open(sys.argv[1]))
token = auth["tokens"]["access_token"]

# The account id lives in the JWT claims; the backend requires it as a header.
payload = token.split(".")[1]
payload += "=" * (-len(payload) % 4)
claims = json.loads(base64.urlsafe_b64decode(payload))
account = claims.get("https://api.openai.com/auth", {}).get("chatgpt_account_id", "")

req = urllib.request.Request(
    "https://chatgpt.com/backend-api/wham/usage",
    headers={"Authorization": f"Bearer {token}", "chatgpt-account-id": account},
)
with urllib.request.urlopen(req, timeout=30) as resp:
    sys.stdout.write(resp.read().decode())
PY
}

case "${1:-used}" in
    json)
        fetch_usage
        ;;
    used)
        fetch_usage | python3 -c \
            "import json,sys; print(json.load(sys.stdin)['rate_limit']['primary_window']['used_percent'])"
        ;;
    check)
        used=$(fetch_usage | python3 -c \
            "import json,sys; print(json.load(sys.stdin)['rate_limit']['primary_window']['used_percent'])")
        if [ "$used" -ge "$CEILING" ]; then
            echo "budget: STOP - weekly window at ${used}%, ceiling is ${CEILING}%" >&2
            exit 1
        fi
        echo "budget: ok - ${used}% used, ceiling ${CEILING}%"
        ;;
    *)
        echo "usage: budget.sh [used|json|check]" >&2
        exit 2
        ;;
esac
