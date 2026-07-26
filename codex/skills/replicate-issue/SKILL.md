---
name: replicate-issue
description: Use when a reported bug needs reproducing and documenting before anyone fixes it - drives the real app through Playwright from a GitLab issue URL, captures screenshots and API responses as evidence, and posts an investigation report back to the issue. Investigates only, never fixes.
model: gpt-5.6-terra
effort: medium
---

# Replicate issue

Reproduce the reported bug against the running application, gather evidence a
developer can act on, and post it to the issue. You are establishing the facts,
not repairing them.

## Start here

Run `.okdev/bin/okdev-state next`. Continue from the phase in
`.okdev/run-state.json` if one exists — the reproduction script may already
exist.

If there is no run state yet — this skill was invoked directly rather than by an orchestrator — create it:

```
.okdev/bin/okdev-state init --workflow replicate-issue
```

`init` prints the existing state and changes nothing when a run is already in progress, so it is safe either way.

## Inputs

- A GitLab issue URL.
- The running application. Frontend and backend URLs from the project's Compose
  file, commonly `http://localhost:3000` and `http://localhost:8000`.
- Stored sessions under `tests/.auth/` for authenticated flows.

## What to do

Read the issue and all its comments first, and separate three things: what the
reporter expected, what they observed, and what the acceptance criteria require.
Comments often carry the detail that makes a bug reproducible.

Write a Playwright script that sets up the preconditions the bug needs — the
users, the data, the starting page — then exercises each acceptance criterion in
turn. Use a real browser against the real application. For a bug involving two
users, drive two browser contexts with separate sessions rather than simulating
the second user. For a timing or polling bug, wait on the actual condition and
confirm the backend state with an API call.

Screenshot every meaningful checkpoint into `test-results/issue{N}-*.png`, and
capture the API responses where the backend is implicated. The screenshots are
the evidence — a report describing what you saw without showing it is much less
useful to whoever fixes this.

Mark each criterion working, broken, or partly working, with actual versus
expected behaviour for anything not working. Then go find the cause: read the
code path the failing behaviour runs through and name the file, function and
line you believe is wrong. A specific suspect is what turns this report into a
short fix.

Note any other bug you trip over on the way, even when it is unrelated to the
report.

If the behaviour turns out to be correct, say so with the evidence. "Could not
reproduce, here is the flow working" is a real and useful result.

Change no product code. Reproduction scripts and screenshots are your only
output.

## Report

Upload the screenshots to GitLab, then post two comments on the issue:

1. **Investigation** — the test setup, findings per acceptance criterion with
   status, a summary of the bugs found with severity and suspected cause, and the
   specific files to look at.
2. **Evidence** — each screenshot with a heading saying what it shows and what
   is wrong in it.

## Done when

Every acceptance criterion has a status backed by evidence, the screenshots are
uploaded, both comments are posted, and no product code changed. Then run
`.okdev/bin/okdev-state complete --workflow replicate-issue`.

## Stop when

Record a blocker with `.okdev/bin/okdev-state block "<reason>"` and end the turn
if the application will not start, the issue lacks enough detail to construct a
reproduction and the comments do not fill the gap, or the flow needs credentials
you do not have.
