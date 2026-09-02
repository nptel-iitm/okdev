---
name: replicate-multiple-issues
description: Use to reproduce a batch of GitLab bugs - runs the replicate-issue investigation against each issue in turn, isolating each in its own sub-agent, and returns a consolidated table of what reproduced, what did not, and what evidence was posted. Investigates only, never fixes.
model: gpt-5.6-terra
effort: medium
---

# Replicate multiple issues

Reproduce and document a set of reported bugs, one investigation per issue.

## Start here

```
.okdev/bin/okdev-state next
```

`.okdev/run-state.json` records which issues have already been investigated.
Resume from there rather than repeating work and double-posting to issues.

On a fresh run:

```
.okdev/bin/okdev-state init --workflow replicate-multi --phase investigate
```

## Inputs

The issue list comes from the invocation, as numbers or URLs. If it named "all
open issues", fetch them from GitLab. If no list was given and none can be
derived, fetch the open issues and say which set you are working on.

State the list — numbers and titles — in your commentary before starting, so the
user can redirect if the scope is wrong.

## What to do

Work through the issues in order. Each one runs in its own sub-agent, given the
issue URL and the application URLs directly in its prompt, doing the
`replicate-issue` investigation: reproduce in a real browser, capture screenshots
and API responses, post the report and evidence to the issue.

The sub-agent returns one line — reproduced, not reproduced, or blocked, with
the issue number. The evidence lives on the GitLab issue, not in your context,
which is what lets this run over twenty issues without drowning.

Record each result as it lands:

```
.okdev/bin/okdev-state note issue:<n> "reproduced - 2 of 3 criteria broken"
```

An issue that fails to investigate does not stop the batch. Record what happened
and continue to the next one — a partial batch with an honest table beats an
aborted run.

No product code changes anywhere in this workflow.

## Report

A table of every issue: number, title, whether it reproduced, and a one-line
finding. Then the totals, and the issues that could not be investigated with the
reason for each.

## Done when

Every issue in the list has a recorded outcome and its evidence posted, or a
stated reason it has none. Then run `.okdev/bin/okdev-state complete`.

## Stop when

Record a blocker with `.okdev/bin/okdev-state block "<reason>"` and end the turn
if GitLab is unreachable, or if the application is not running so nothing can be
reproduced at all.
