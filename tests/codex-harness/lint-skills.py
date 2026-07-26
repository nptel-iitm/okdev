#!/usr/bin/env python3
"""Static conformance checks for the Codex skill tree.

These run for free - no model calls - and catch the failure modes the
investigation in issue #15 identified before a single token is spent:

  * a skill that cannot be resumed after compaction (no durable run state)
  * a loop whose only exit is a human ("STOP and ask the user")
  * a spawn chain deeper than one level (breaks on Luna, multi_agent v1)
  * prescriptive absolutes that GPT-5.6 follows literally into a corner
  * a description too weak for the skill to be discovered at all - Codex
    shows the model only name + description + path, never the body

Usage: lint-skills.py [skills-dir]   (default: codex/skills)
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
VALID_MODELS = {"gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna"}
VALID_EFFORTS = {"low", "medium", "high", "xhigh", "max"}

# Phrases whose only exit edge is a human being present.
HUMAN_GATE = re.compile(
    r"(STOP and ask the user|stop and ask the user|wait for user approval"
    r"|Wait for confirmation|ask the user and wait|escalate to the user)",
    re.IGNORECASE,
)

# Unbounded repetition with no stated ceiling.
UNBOUNDED = re.compile(
    r"(until (it|they|the \w+) (pass|passes|is approved|converge)"
    r"|No exceptions\.|loop back to Phase|Repeat until)",
    re.IGNORECASE,
)

ABSOLUTES = re.compile(r"\b(NEVER|ALWAYS|MUST NOT|No exceptions)\b")

# A skill telling a sub-agent to go read its own instructions. GPT-5.6's
# harness forbids delegating skill reading, so this silently no-ops.
DELEGATED_READ = re.compile(
    r"(spawn|invoke|launch)[^.\n]{0,60}(sub-?agent)[^.\n]{0,80}"
    r"(read|load|use)[^.\n]{0,40}(SKILL\.md|skill)",
    re.IGNORECASE,
)


def parse_frontmatter(text: str) -> tuple[dict, str]:
    if not text.startswith("---"):
        return {}, text
    end = text.find("\n---", 3)
    if end == -1:
        return {}, text
    block = text[3:end]
    body = text[end + 4 :]
    meta: dict[str, str] = {}
    for line in block.splitlines():
        if ":" in line and not line.startswith(" "):
            key, _, value = line.partition(":")
            meta[key.strip()] = value.strip()
    return meta, body


def check(path: Path) -> tuple[list[str], list[str]]:
    text = path.read_text()
    meta, body = parse_frontmatter(text)
    name = path.parent.name
    errors: list[str] = []
    warnings: list[str] = []

    for field in ("name", "description", "model", "effort"):
        if not meta.get(field):
            errors.append(f"frontmatter is missing '{field}'")

    if meta.get("name") and meta["name"] != name:
        errors.append(f"frontmatter name '{meta['name']}' != directory '{name}'")

    if meta.get("model") and meta["model"] not in VALID_MODELS:
        errors.append(f"model '{meta['model']}' is not a GPT-5.6 slug")

    if meta.get("effort") and meta["effort"] not in VALID_EFFORTS:
        errors.append(f"effort '{meta['effort']}' is not a valid reasoning level")

    desc = meta.get("description", "")
    if desc and len(desc) < 60:
        warnings.append(
            f"description is {len(desc)} chars; it is the only discovery "
            "surface Codex sees, so say when to use the skill"
        )

    # Durable state is what makes a skill survive compaction, and Codex drops
    # skills between turns - so every skill has to be able to re-enter itself.
    if "run-state.json" not in body:
        errors.append("does not read or write .okdev/run-state.json")

    for pattern, label in ((HUMAN_GATE, "human-only exit"), (UNBOUNDED, "unbounded loop")):
        for match in pattern.finditer(body):
            line = body[: match.start()].count("\n") + 1
            errors.append(f"{label} at body line {line}: {match.group(0)!r}")

    if DELEGATED_READ.search(body):
        errors.append("delegates skill reading to a sub-agent; GPT-5.6 forbids this")

    absolutes = ABSOLUTES.findall(body)
    if len(absolutes) > 6:
        warnings.append(
            f"{len(absolutes)} absolute directives; GPT-5.6 follows these "
            "literally - reserve them for real invariants"
        )

    if "## Done when" not in body:
        errors.append("has no '## Done when' completion bar")

    return errors, warnings


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO / "codex" / "skills"
    skills = sorted(root.glob("*/SKILL.md"))
    if not skills:
        print(f"lint: no skills found under {root}")
        return 1

    total_errors = 0
    total_warnings = 0
    for skill in skills:
        errors, warnings = check(skill)
        total_errors += len(errors)
        total_warnings += len(warnings)
        if errors or warnings:
            print(f"\n{skill.parent.name}")
            for err in errors:
                print(f"  ERROR   {err}")
            for warn in warnings:
                print(f"  warning {warn}")

    print(f"\n{len(skills)} skills checked - {total_errors} errors, {total_warnings} warnings")
    return 1 if total_errors else 0


if __name__ == "__main__":
    sys.exit(main())
