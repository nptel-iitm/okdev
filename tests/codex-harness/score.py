#!/usr/bin/env python3
"""Scores a completed harness run against a fixture's expectations.

Everything here is deterministic and machine-checkable. Qualitative
comparison against the Claude baseline is a separate judging step - this
file only answers "did the skill do the job, and did it terminate".

A fixture's expect.json looks like:

    {
      "must_not_time_out": true,
      "max_turns": 12,
      "max_duration_seconds": 600,
      "files_exist": [".okdev/run-state.json"],
      "files_match": [{"path": "calc.py", "pattern": "return a \\\\+ b"}],
      "files_absent": ["blocked.md"],
      "commands": [{"cmd": "python3 -m pytest -q", "expect_exit": 0}],
      "run_state": {"phase": "complete"},
      "final_message_matches": "(?i)all tests pass"
    }

Usage: score.py <run-dir> <expect.json>
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path


class Scorer:
    def __init__(self, run_dir: Path, expect: dict):
        self.run_dir = run_dir
        self.work = run_dir / "work"
        self.expect = expect
        self.checks: list[tuple[str, bool, str]] = []

    def record(self, name: str, passed: bool, detail: str = "") -> None:
        self.checks.append((name, passed, detail))

    def run(self) -> None:
        result = json.loads((self.run_dir / "result.json").read_text())

        if self.expect.get("must_not_time_out", True):
            self.record(
                "terminated on its own",
                not result["timed_out"],
                f"ran {result['duration_seconds']}s of {result['timeout_seconds']}s",
            )

        self.record(
            "exited cleanly",
            result["exit_code"] == 0,
            f"exit code {result['exit_code']}",
        )

        if (limit := self.expect.get("max_turns")) is not None:
            self.record(
                f"used at most {limit} turns",
                result["turns"] <= limit,
                f"{result['turns']} turns",
            )

        if (limit := self.expect.get("max_duration_seconds")) is not None:
            self.record(
                f"finished within {limit}s",
                result["duration_seconds"] <= limit,
                f"{result['duration_seconds']}s",
            )

        for rel in self.expect.get("files_exist", []):
            self.record(f"created {rel}", (self.work / rel).exists())

        for rel in self.expect.get("files_absent", []):
            self.record(f"did not create {rel}", not (self.work / rel).exists())

        for spec in self.expect.get("files_match", []):
            path = self.work / spec["path"]
            if not path.exists():
                self.record(f"{spec['path']} matches /{spec['pattern']}/", False, "file missing")
                continue
            found = re.search(spec["pattern"], path.read_text(errors="replace")) is not None
            self.record(f"{spec['path']} matches /{spec['pattern']}/", found)

        for spec in self.expect.get("commands", []):
            proc = subprocess.run(
                spec["cmd"], shell=True, cwd=self.work,
                capture_output=True, text=True, timeout=spec.get("timeout", 300),
            )
            want = spec.get("expect_exit", 0)
            tail = (proc.stdout + proc.stderr).strip().splitlines()[-3:]
            self.record(
                f"`{spec['cmd']}` exits {want}",
                proc.returncode == want,
                f"exit {proc.returncode}: " + " | ".join(tail),
            )

        if (wanted := self.expect.get("run_state")) is not None:
            state_path = self.work / ".okdev" / "run-state.json"
            if not state_path.exists():
                self.record("run-state.json is present", False)
            else:
                state = json.loads(state_path.read_text())
                self.record("run-state.json is present", True)
                for key, value in wanted.items():
                    self.record(
                        f"run-state.{key} == {value!r}",
                        state.get(key) == value,
                        f"got {state.get(key)!r}",
                    )

        if (pattern := self.expect.get("final_message_matches")) is not None:
            message = (self.run_dir / "last-message").read_text(errors="replace")
            self.record(
                f"final message matches /{pattern}/",
                re.search(pattern, message) is not None,
            )

    def report(self) -> int:
        passed = sum(1 for _, ok, _ in self.checks if ok)
        for name, ok, detail in self.checks:
            mark = "PASS" if ok else "FAIL"
            suffix = f"  ({detail})" if detail else ""
            print(f"  {mark}  {name}{suffix}")
        print(f"\n{passed}/{len(self.checks)} checks passed")

        summary = {
            "run_id": self.run_dir.name,
            "passed": passed,
            "total": len(self.checks),
            "checks": [
                {"name": n, "passed": ok, "detail": d} for n, ok, d in self.checks
            ],
        }
        (self.run_dir / "score.json").write_text(json.dumps(summary, indent=2))
        return 0 if passed == len(self.checks) else 1


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    run_dir = Path(sys.argv[1])
    expect = json.loads(Path(sys.argv[2]).read_text())
    scorer = Scorer(run_dir, expect)
    scorer.run()
    return scorer.report()


if __name__ == "__main__":
    sys.exit(main())
