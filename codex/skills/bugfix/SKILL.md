---
name: bugfix
description: Use to fix a bug on an existing project end to end - validates the environment, specifies the bug and its acceptance criteria, implements the fix through a reviewed merge request, runs regression-focused testing, spot-checks in a browser, and reports. Skips architecture and project setup. For new projects use kickoff instead.
model: gpt-5.6-sol
effort: medium
---

# Bugfix

Drive one bug from report to verified fix on a project that already exists.
Invoke as `$bugfix`.

## Start here

Always begin with:

```
.okdev/bin/okdev-state next
```

Continue from the reported phase if a run is in progress. This workflow often
spans a compaction, and `.okdev/run-state.json` is what tells you the issue
number, the branch, and how many review rounds the MR has already used.

On a fresh run:

```
.okdev/bin/okdev-state init --workflow bugfix --phase environment
```

This skill assumes an existing repo with a GitLab project and an architecture to
fix against. If there is none, say so and point the user at `$kickoff`.

## Workspace

Work in the current directory unless told otherwise, or clone fresh into
`mktemp -d /tmp/okdev-XXXXXX` when asked. Record it:

```
.okdev/bin/okdev-state note workspace "<absolute path>"
```

## Phase: environment

Confirm Docker, GitLab reachability, a working API token from `.mcp.json`, and
Playwright. `block` with the exact failing command if any check fails.

## Phase: specify

Delegate to `requirements-agent` with the bug report — issue URL, description, or
a Whisper transcription of audio — plus the parts of the codebase it touches.
Output goes to `{project}/.okdev/requirements.md` and states: expected versus
actual behaviour, reproduction steps, the affected components, and the
acceptance criteria the fix must meet.

Ensure a GitLab issue exists for the bug, creating one with the reproduction
steps and criteria if it does not, so the board stays the source of truth.

Where the report is ambiguous about which behaviour is actually correct, and both
readings are plausible, `block` with the two options. Fixing the wrong behaviour
costs more than asking.

Record the issue number:

```
.okdev/bin/okdev-state note issue "<iid>"
```

## Phase: implement

Delegate to `dev-agent`: branch, fix, and a test that fails on the old code and
passes on the new one — a regression test is what stops this bug returning.

Then run the review loop, counting each round before it starts:

```
.okdev/bin/okdev-state loop-bump review:mr-{iid} --limit 3
```

Exit 0 means run the round: a fresh `code-review-agent` reviews the current
head; APPROVED merges and ends the loop; CHANGES REQUESTED goes back to the
dev-agent, which resolves every MUST FIX and gets the full suite green before
the next round. Exit 3 means the budget is spent — comment the outstanding
findings on the MR, label the issue `blocked`, `block` with what is still
disputed, and end the turn.

## Phase: testing

Delegate to `test-planner-agent`, scoped to the fix and its blast radius:
regression coverage for this bug, the unit and integration tests around the
changed components, the E2E flows that touch it, UI scoring on affected pages,
and load testing only if the bug was performance-related.

## Phase: spot-check

Delegate to `manual-spot-checker` for the bug's own reproduction steps plus the
adjacent flows, driven through a real browser. Confirm the original bug is gone
and nothing beside it broke.

## Phase: delivery

Delegate to `delivery-agent` for `{project}/.okdev/delivery-report.md`: what was
wrong, the root cause, what changed and why, the test results including the
regression test, and before-and-after screenshots where they exist.

## Log

Append each phase transition and its outcome to
`{project}/.okdev/orchestrator-log.md`.

## Done when

The fix is merged, a regression test covering it passes, the spot-check confirms
the reported behaviour is gone, and the delivery report exists. Then run
`.okdev/bin/okdev-state complete`.

## Stop when

Record a blocker with `.okdev/bin/okdev-state block "<reason>"` and end the turn
if the environment checks fail, if the correct behaviour is genuinely ambiguous,
if the review loop exhausts its budget, or if the bug cannot be reproduced at all
— an unreproducible bug needs more information, and `.okdev/blocked.md` should
say exactly what.
