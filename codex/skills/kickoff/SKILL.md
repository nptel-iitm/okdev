---
name: kickoff
description: Use to build a project from scratch end to end - validates the environment, gathers requirements, designs the architecture, sets up GitLab, drives implementation through review, runs the full test strategy, and produces a delivery report. Entry point for new work. For fixing a bug on an existing project use bugfix instead.
model: gpt-5.6-sol
effort: medium
---

# Kickoff

Drive a complete development lifecycle: requirements, design, tickets, code,
tests, delivery. Invoke as `$kickoff`.

## Start here

Always begin with:

```
.okdev/bin/okdev-state next
```

If it reports an existing run, continue from that phase. This workflow runs long
enough that a compaction is normal, and after one you will have the skill text
but not your own history — `.okdev/run-state.json` is what tells you whether
requirements are already written and which issues already merged. Do not redo a
phase listed in `phases_done`.

On a fresh run:

```
.okdev/bin/okdev-state init --workflow kickoff --phase environment
```

## Workspace

Work in the current directory unless the invocation named another path or asked
for a clean clone. For a clean clone, take the remote from
`git remote get-url origin`, clone into `mktemp -d /tmp/okdev-XXXXXX`, and tell
the user the path. Record the choice:

```
.okdev/bin/okdev-state note workspace "<absolute path>"
```

Everything below resolves `{project}` to that path.

## Phase: environment

Confirm Docker responds to `docker info`, GitLab answers at its configured URL,
the API token in `.mcp.json` authenticates against it, and
`npx playwright --version` works. If any check fails, `block` with the exact
command and error — every later phase depends on these, so continuing produces
work that cannot be verified.

## Phase: requirements

Delegate to `requirements-agent`. Transcribe any audio input first with Whisper
via Docker. The output is `{project}/.okdev/requirements.md`.

Read its ambiguities list. Resolve the ones you can from the source material or
from ordinary convention, and record the resolution. If one would materially
change what gets built — two incompatible readings of the core feature — `block`
with both options rather than picking one and building the wrong product.

## Phase: architecture

Delegate to `architect-agent`, and to `ui-designer-agent` as well when the
product has a UI. Output is `{project}/.okdev/architecture.md`.

Where the requirements did not name a stack, the architect proposes one, and the
default is Python and Django with PostgreSQL, pytest and Playwright, on Docker
Compose. Record the stack and state it clearly in your commentary as an
assumption you are proceeding on, so the user can redirect early if it is wrong:

```
.okdev/bin/okdev-state note tech-stack "<stack>, chosen by <requirement or default>"
```

## Phase: setup and implementation

Delegate to `tech-lead-agent`, which creates the GitLab project and board,
breaks the architecture into issues, and drives each one through the bounded
review loop to a merge.

If it comes back blocked, record what merged and what did not, and continue to
testing with what exists — a partially built system with an honest report is
more useful than a stalled run.

## Phase: testing

Delegate to `test-planner-agent`. It plans the coverage matrix, runs every
category in dependency order, files an issue for each failure, and re-runs a
failed category within its own round budget. Failures that survive their budget
stay open and get reported; they do not send this phase back to implementation
indefinitely.

## Phase: delivery

Delegate to `delivery-agent` for `{project}/.okdev/delivery-report.md`, then
present the summary to the user.

## Log

Append each phase transition and its outcome to
`{project}/.okdev/orchestrator-log.md` as you go.

## Done when

Requirements, architecture, test report and delivery report all exist, every
issue is merged or explicitly open with a reason, and the delivery report states
an honest readiness verdict. Then run `.okdev/bin/okdev-state complete`.

Delivering a working subset with a clear list of what is unfinished is success.

## Stop when

Record a blocker with `.okdev/bin/okdev-state block "<reason>"` and end the turn
if the environment checks fail, if GitLab is unreachable, or if a requirement
ambiguity would change what product gets built. `blocked.md` records what
finished and how to resume, so re-invoking `$kickoff` afterwards continues from
there rather than starting again.
