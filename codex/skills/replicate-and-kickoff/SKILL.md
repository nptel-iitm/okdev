---
name: replicate-and-kickoff
description: Use to take one reported bug from report to merged fix - reproduces it in a browser and posts the evidence, then drives the fix through the bugfix lifecycle to a reviewed and merged MR. Combines replicate-issue and bugfix into a single pass over one issue.
model: gpt-5.6-sol
effort: medium
---

# Replicate and fix

Prove the bug is real, then fix it. Two stages over a single issue, in order,
because a fix written before the bug is understood usually treats a symptom.

## Start here

```
.okdev/bin/okdev-state next
```

If `.okdev/run-state.json` shows the reproduction stage already finished, go
straight to the fix — re-investigating a bug you already documented wastes the
turn and posts duplicate evidence to the issue.

On a fresh run:

```
.okdev/bin/okdev-state init --workflow replicate-and-kickoff --phase replicate
```

## Inputs

A GitLab issue URL, and the running application.

## Phase: replicate

Run the `replicate-issue` investigation: reproduce the reported behaviour in a
real browser, capture screenshots and the relevant API responses, mark each
acceptance criterion working or broken, identify the likely cause down to a file
and function, and post the report and evidence to the issue.

Record the outcome:

```
.okdev/bin/okdev-state note reproduced "yes - failing at <file>:<function>"
.okdev/bin/okdev-state set-phase fix
```

If the reported behaviour turns out to be correct, post that finding with the
evidence and run `okdev-state complete`. "Cannot reproduce, here is the flow
working" is a finished, useful outcome — do not proceed to fix a bug you could
not observe.

## Phase: fix

Run the `bugfix` lifecycle against the issue, starting from the specification
your own investigation just produced. That means: a dev-agent branches,
implements the fix and writes a regression test that fails on the old code, then
the bounded review loop:

```
.okdev/bin/okdev-state loop-bump review:mr-{iid} --limit 3
```

Exit 0 runs a round with a fresh reviewer against the current head — APPROVED
merges and ends the loop, CHANGES REQUESTED goes back for the MUST FIX items and
a green suite. Exit 3 means the budget is spent: comment the outstanding
findings on the MR, label the issue `blocked`, `block` with what remains
disputed, and end the turn.

Then confirm the fix against the original reproduction: run the same steps in
the browser and check the reported behaviour is gone.

## Report

One short summary: whether it reproduced, the root cause, what changed, the MR
number and whether it merged, and whether the reproduction now passes.

## Done when

The investigation is posted to the issue, the fix is merged with a regression
test covering it, and the original reproduction steps now pass. Then run
`.okdev/bin/okdev-state complete`.

## Stop when

Record a blocker with `.okdev/bin/okdev-state block "<reason>"` and end the turn
if the application will not start, if the review loop exhausts its budget, or if
the fix would require a change the issue does not authorise — a bug whose real
cause is an architectural decision needs a decision, not a patch.
