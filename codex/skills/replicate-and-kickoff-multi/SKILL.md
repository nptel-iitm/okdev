---
name: replicate-and-kickoff-multi
description: Use to take a batch of reported bugs from report to merged fix - runs the full replicate-then-fix pass over each issue in turn, one fully finished before the next starts, each isolated in its own sub-agent, and returns a consolidated table of outcomes.
model: gpt-5.6-sol
effort: medium
---

# Replicate and fix, batch

Run a complete reproduce-then-fix pass over each issue in a list, finishing one
before starting the next.

## Start here

```
.okdev/bin/okdev-state next
```

`.okdev/run-state.json` records which issues are done and what happened to each.
A batch of ten issues will outlive several compactions, so resume from that
record rather than from memory — re-running a finished issue can reopen work
that already merged.

On a fresh run:

```
.okdev/bin/okdev-state init --workflow replicate-and-kickoff-multi --phase process
```

## Inputs

The issue list from the invocation, as numbers or URLs, or "all open issues" in
which case fetch them from GitLab. State the list — numbers and titles — in your
commentary before starting so the user can redirect if the scope is wrong.

## What to do

Process the issues strictly in order, one at a time. Each gets a fresh sub-agent
running the full replicate-and-kickoff pass, with the issue URL and application
URLs in its prompt. Wait for it to finish before starting the next.

The sequencing is deliberate. Fixes to two bugs in the same area conflict when
they land together, and reproducing a later bug is unreliable while an earlier
fix is still in flight. The isolation is deliberate too: each issue's
reproduction evidence, dev work, review rounds and test output stay inside its
sub-agent, and only a one-line outcome comes back, so a twenty-issue batch costs
the parent almost nothing.

Record each outcome as it lands:

```
.okdev/bin/okdev-state note issue:<n> "MR !42 merged"
```

One issue failing does not stop the batch. Log it and continue — the value of a
batch run is the issues it does finish.

## Report

A table of every issue: number, title, whether it reproduced, the MR and whether
it merged, or the reason it did not finish. Then the totals: processed,
fixed and merged, not reproduced, blocked.

## Done when

Every issue in the list has an outcome recorded, and the table reflects it.
Then run `.okdev/bin/okdev-state complete`.

A batch where six merged, two did not reproduce and two are blocked is complete.
Reporting the split accurately is the deliverable.

## Stop when

Record a blocker with `.okdev/bin/okdev-state block "<reason>"` and end the turn
if GitLab is unreachable or the application will not start, since neither stage
can run for any issue in the batch.
