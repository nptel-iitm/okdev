#!/usr/bin/env bash
# Verifies that every skill in a tree actually registers in Codex's skill
# catalog, and prints the catalog exactly as the model will see it.
#
# This costs zero tokens: `codex debug prompt-input` renders the model-visible
# prompt locally without calling the API. Codex only ever shows the model a
# skill's name, description and path - never the body - so a skill that is
# missing or badly described here can never be selected, no matter how good
# its instructions are.
#
# Usage: check-catalog.sh [skills-dir]   (default: repo codex/skills)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAB="${OKDEV_LAB:-/run/media/rishav/data/okdev-codex-lab}"
IMAGE="${OKDEV_CODEX_IMAGE:-okdev-codex-test:0.145.0}"
SKILLS="${1:-$REPO_DIR/codex/skills}"

STAGE="$LAB/catalog-check"
rm -rf "$STAGE"
mkdir -p "$STAGE/codexhome/skills" "$STAGE/work" "$STAGE/agenthome"
cp "${CODEX_HOME:-$HOME/.codex}/auth.json" "$STAGE/codexhome/auth.json"
printf 'model = "gpt-5.6-terra"\n\n[projects."/work"]\ntrust_level = "trusted"\n' \
    > "$STAGE/codexhome/config.toml"
cp -r "$SKILLS"/* "$STAGE/codexhome/skills/" 2>/dev/null || true
git -C "$STAGE/work" init -q

# prompt-input renders from the working directory and takes no -C flag, so the
# workspace is set with docker's -w. Network stays on because Codex refreshes
# its model catalogue on start; no model call is made.
docker run --rm \
    --user "$(id -u):$(id -g)" \
    -w /work \
    -v "$STAGE/codexhome:/codexhome" \
    -v "$STAGE/work:/work" \
    -v "$STAGE/agenthome:/agenthome" \
    -e CODEX_HOME=/codexhome -e HOME=/agenthome \
    "$IMAGE" \
    codex debug prompt-input 2>"$STAGE/stderr.log" \
    > "$STAGE/prompt-input.json"

SKILLS="$SKILLS" python3 - "$STAGE/prompt-input.json" <<'PY'
import json, os, sys
from pathlib import Path

items = json.load(open(sys.argv[1]))
catalog = ""
for item in items:
    for part in item.get("content", []):
        text = part.get("text", "")
        if "### Available skills" in text:
            catalog = text
            role = item.get("role")

if not catalog:
    print("catalog: no skills section found in the rendered prompt")
    sys.exit(1)

print(f"catalog is injected as a '{role}'-role message\n")
listed = {}
for line in catalog.splitlines():
    if line.startswith("- ") and ": " in line:
        name, _, rest = line[2:].partition(": ")
        listed[name] = rest

expected = sorted(p.parent.name for p in Path(os.environ["SKILLS"]).glob("*/SKILL.md"))
missing = [name for name in expected if name not in listed]

for name in expected:
    entry = listed.get(name)
    status = "ok " if entry else "MISSING"
    chars = len(entry.split(" (file:")[0]) if entry else 0
    print(f"  {status} {name:<28} {chars} chars of description")

print(f"\n{len(expected) - len(missing)}/{len(expected)} skills registered")
if missing:
    print("missing: " + ", ".join(missing))
    sys.exit(1)
PY
