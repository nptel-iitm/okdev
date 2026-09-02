---
name: kickoff-multi
description: Use to run the full kickoff lifecycle over a batch of GitLab issues sequentially - each issue is driven to completion in its own isolated sub-agent before the next one starts, and the run ends with a consolidated table of outcomes. For a single issue use kickoff directly.
model: gpt-5.6-sol
effort: medium
---

# Kickoff, batch

Drive the kickoff lifecycle over a list of issues, finishing each one before
starting the next.

## Start here

```
.okdev/bin/okdev-state next
```

`.okdev/run-state.json` records which issues are already done and how each
finished. A batch outlives several compactions, so resume from that record — an
issue re-run from scratch can duplicate branches and merge requests that already
exist.

On a fresh run:

```
.okdev/bin/okdev-state init --workflow kickoff-multi --phase process
```

## Inputs

The issue list from the invocation, as numbers or URLs, or "all open issues" in
which case fetch them from GitLab. State the list — numbers and titles — in your
commentary before starting, so the user can redirect if the scope is wrong.

## What to do

Process the issues in order, one at a time. Each gets a fresh sub-agent running
the kickoff lifecycle against that single issue, with everything it needs in its
prompt. Wait for it to return before starting the next.

Sequential is the right shape here even though the issues look independent: two
lifecycles running at once produce conflicting branches in the same repo and
compete over the same board columns. The isolation matters for a different
reason — each issue's requirements, design, dev work, review rounds and test
output stay inside its sub-agent, and only a one-line outcome returns, so the
parent stays light across a long batch.

Record each outcome as it lands:

```
.okdev/bin/okdev-state note issue:<n> "MR !42 merged"
```

One issue failing does not stop the batch. Log the failure and continue.

## Report

A table of every issue: number, title, and outcome — merged, still in review,
blocked with the reason, or skipped. Then the totals.

## Done when

Every issue in the list has a recorded outcome and the table reflects it. Then
run `.okdev/bin/okdev-state complete`.

A batch where most issues merged and a few are blocked with reasons is a
complete run.

## Stop when

Record a blocker with `.okdev/bin/okdev-state block "<reason>"` and end the turn
if GitLab is unreachable, or if the environment checks fail in a way that
affects every issue in the batch.
