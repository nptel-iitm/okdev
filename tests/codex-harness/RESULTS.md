# Codex harness results

Every run below executed the real Codex CLI (0.145.0) inside Docker with a
private `CODEX_HOME`, against the ChatGPT Pro plan. Raw artifacts — event
stream, final message, workspace, usage — are under `$OKDEV_LAB/runs/<id>/`.

## The failure from issue #15, reproduced and fixed

The report was that `kickoff` and `bugfix` run forever under Codex. The
investigation attributed that to loop counters living only in the model's head,
which are lost when the context is compacted. This is the controlled test of
that claim.

**Setup.** A merge request under a reviewer that can never be satisfied: every
invocation returns CHANGES REQUESTED with a different finding. Two review
rounds have already happened. The skill's budget is three rounds, so exactly
one round remains.

The reviewer leaks nothing about the round count — no round number in its
output, and its invocation log lives outside the workspace. The prompt does not
mention prior rounds either. A fresh session is compaction taken to its limit:
no conversational memory at all, so the only thing that can carry the count is
what the skill wrote to disk.

**Result.**

```
                         rounds run    total vs      recorded a
                         this session  3-round budget blocker
codex/skills  (exp-07)        1          3 of 3        yes
claude/skills (exp-08)        3          5 of 3        no
```

The Codex tree read `.okdev/run-state.json`, saw two rounds spent, ran the one
that remained, and wrote `.okdev/blocked.md` naming what was still disputed.

The control started counting at one. Its own final message reports "Round 1,
Round 2, Round 3 — budget exhausted, stopped and escalated exactly as
required", which is a correct-looking summary of a run that had just spent five
rounds against a budget of three. Nothing in it is dishonest; the model simply
had no way to know. The overrun is not bounded at 5 either: every subsequent
context loss grants another three rounds, which is the runaway the ticket
described.

## What does not reproduce it

Worth recording, because it shaped the test above.

A short run does not reproduce the bug. With the same impossible reviewer but a
single uninterrupted session, the old skills stop at three rounds correctly
(`cal-07`), and so do the new ones (`cal-05`). Forcing auto-compaction with
`model_auto_compact_token_limit` did not reproduce it either (`exp-02`): the
model stops at three rounds well before the window fills, so compaction never
fires. The bug needs a run long enough to lose context, which is why it showed
up in a week of real use and not in a quick test.

Two earlier attempts were invalid and were rerun:

- `cal-06` installed `codex/AGENTS.md` into the control's workspace, handing
  the old skills the new operating rules. `run-codex.sh --runtime` now selects
  the runtime so a control gets `CLAUDE.md` and no state helper.
- `exp-05`/`exp-06` leaked the round count to both trees, through a counter
  file inside the workspace, a round number in the review output, and a line in
  the prompt. All three were removed before `exp-07`/`exp-08`.

## Skill parity against Claude

`unit-tests-basic`: a small pricing module whose `shipping_cost` docstring
promises free shipping "at or above" the threshold while the code uses a strict
`>`. An order landing exactly on the threshold is charged. Nothing in the
fixture points at the bug.

Every run found it, reported it against the docstring, and left the failing
test in place rather than editing production code to get a green suite.

```
                        tests  failing  line cov  found the bug  duration
Claude subagent           27      1       100%        yes         133s
codex + Sol xhigh         15      1       100%        yes         217s
codex + Terra medium      13      1       100%        yes         123s
codex + Terra medium (2)  11      1       100%        yes          80s
codex + Luna medium       13      2       100%        yes          96s
```

All five reached the same conclusion. Claude wrote roughly twice as many tests
for the same coverage. Luna reported two failures rather than one, correctly:
it traced the same defect through `order_total` as a second call site.

All four Codex runs scored 11/11 on the fixture's machine-checkable
expectations, including writing the report to the expected path and leaving
run state in `complete`.

## Skill coverage

Each row is a Codex run scored against the fixture's machine-checkable
expectations.

```
skill                  fixture                  what it had to do          score
unit-test-runner       unit-tests-basic         find a planted boundary    11/11
                                                bug, report it, leave the
                                                failing test in place
code-review-agent      review-good-code         approve correct code       8/8
                                                without inventing a
                                                blocking finding
code-review-agent      review-buggy-code        catch SQL injection as     10/10
                                                MUST FIX, request changes
tech-lead-agent        review-never-converges   stop at 3 rounds, refuse   10/10
                                                to merge, record a blocker
tech-lead-agent        (resumed session)        resume the round count     see above
                                                from disk after context
                                                is lost
requirements-agent     requirements-vague       turn a 12-line brief into  11/11
                                                requirements plus stated
                                                ambiguities
architect-agent        architect-from-reqs      design the system, stack,  13/13
                                                Compose topology, risks,
                                                build order
e2e-test-runner        blocked-no-app           block in 33s when the app  8/8
                                                is unreachable
kickoff                kickoff-blocked-env      block when the environment 9/9
                                                preconditions fail
integration-test-      integration-sqlite       map every boundary, test   11/11
  runner                                        against the real database,
                                                catch a silent no-op
e2e-test-runner        webapp-flows             drive a real browser over  11/11
                                                6 flows, catch 2 planted
                                                product defects
ui-screenshot-scorer   webapp-flows             screenshot 2 pages x 3     12/12
                                                viewports, score 7 criteria
                                                each, fail the bad pages
manual-spot-checker    webapp-flows             run 8 manual cases by hand 12/12
                                                in a browser, give an
                                                honest readiness verdict
bugfix                 (resumed mid-run)        skip finished phases, fix  see above
                                                the bug, add a regression
                                                test, complete
```

One assertion was wrong rather than one skill: the architecture fixture
originally required the literal heading "implementation order", and the run
produced "Dependency-ordered implementation plan". The skill asks for a
dependency-ordered build sequence, which is what it delivered, so the assertion
was corrected and the stored run rescored.

The `bugfix` resumption run has a control worth quoting. Same staged situation,
old skills, no state on disk:

```
                 input tokens   phases re-run        prior artifact
codex/skills        344k        none                 preserved
claude/skills      1085k        0, 1 and 2           requirements.md overwritten
```

Both produced a correct fix. The difference is 3.2x the tokens and the loss of
the previous phase's output.

### The browser fixture

`webapp-flows` is a small notes application served over HTTP, with defects
planted in three different places so a skill has to actually look:

- a functional one — a note with no title is accepted, though the README says
  it must be rejected with a validation message;
- a responsive one — a fixed 900px container, so the page overflows at 768px
  and 375px;
- a contrast one — hint text at `#dcdcd6` on a `#fbfbf8` background.

Each skill found what falls in its remit. The E2E runner failed the
title-validation flow and the 375px flow. The scorer measured a 900px document
width against a 375px viewport rather than asserting it by eye, and failed
every page. The spot-checker caught both, plus the absolutely-positioned header
identity that the scorer had missed, and concluded "not ready for general
users" with two issues written up well enough to file.

These runs used `Dockerfile.browser`, a variant image with Playwright and its
browsers, selected with `run-codex.sh --image`.

### Repeats

The behaviours most likely to be flaky were run more than once. Approving clean
code, stopping a review loop at its budget, and the unit-test pass all repeated
with identical outcomes (8/8, 10/10, 11/11 on the second and third runs).

## Against a real GitLab project

`setup-gitlab-lab.sh` creates `okdev/notes-lab`: a small notes service with a
JSON API, a static frontend and a SQLite store, seeded with three defects in
three different layers and a filed issue for each.

- **#1** the API accepts a note with a blank title, though the README says it
  must be rejected;
- **#2** `list_notes` takes an `owner` argument and never uses it, so any
  signed-in account can read every other account's notes;
- **#3** a fixed 900px container makes the page unusable at phone widths.

```
run  skill                       what happened                          score
g01  replicate-issue             reproduced #2 in two independent       8/8
                                 browser sessions, uploaded 2
                                 screenshots, posted the report, named
                                 app/store.py:33-38, changed no code
g02  tech-lead-agent             branch -> MR !1 -> review -> merged;    8/8
                                 issue #1 auto-closed; 47-line
                                 regression test added
g03  replicate-multiple-issues   investigated #2 and #3 in turn, posted  7/7
                                 evidence to both
g04  load-tester                 ran k6 from the grafana/k6 image as a   8/8
                                 sibling container, 105,495 requests,
                                 measured p95 52ms / p99 68ms / 0
                                 errors / 1,055 rps
g05  replicate-and-kickoff       reproduced #2, fixed it, MR !2 merged,  6/6
                                 issue #2 closed, 5 tests green
g06  test-planner-agent          planned 7 categories with a coverage    9/9
                                 matrix, ran them, wrote a report with
                                 a readiness verdict
g08  ui-designer-agent           specified the fix for #3 across three   10/10
                                 viewports with tokens and contrast
                                 targets, and changed no code
g09  delivery-agent              traced requirements, verified the       9/9
                                 deployment path, reported "NOT READY
                                 TO DELIVER" as a complete run
g10  kickoff-multi               drove issues #4 and #5 through the      6/6
                                 lifecycle in sequence: two more MRs
                                 merged, both issues closed
```

Final state of the project, read back from GitLab rather than from any agent's
report: four merge requests merged, four of five issues closed, 14 tests green.
Issue #3 is still open because it was only ever investigated, never assigned
for a fix — which is correct.

Every merged change was verified independently by cloning `main` and exercising
the behaviour:

```
blank title            400        health endpoint (no auth)   200 {"status":"ok"}
sam reads demo's notes []         limit=99999                 200 (clamped)
                                  limit=abc / limit=0         400
```

Both merges were verified independently of the agent's own report, by cloning
`main` afterwards and re-running the original reproduction:

```
issue #1   POST /api/notes {"title":""}   before: 201    after: 400
issue #2   sam reads demo's notes         before: leaks  after: []
```

`docker.sock` is mounted for the load test via `run-codex.sh --docker`, so the
skill runs k6 in a container the way its instructions require rather than being
quietly excused from it. The k6 container is a sibling, not a child, which the
prompt says explicitly — the skill worked out the `--network host` and script
mounting itself.

### A defect this campaign found

Run against a product with three failing requirements, `delivery-agent` wrote a
complete and accurate report headed "not ready to deliver", and then recorded a
blocker. Both were defensible readings of its own text, which told it to report
bad news honestly *and* to block when requirements were not satisfied. That is
the contradiction OpenAI's 5.6 guidance warns about, and it has a real cost:
blocking withholds the report someone needs in order to act on the bad news.

The skill now says one thing — a failing product is delivered as "not ready"
with the failures named, and blocking is reserved for when no honest report can
be produced at all. Re-run against the identical workspace (`g09`), it completed
with the same verdict and no blocker.

This is the case for testing skills against something real. Nine of the ten
GitLab runs passed first time; the tenth found a genuine contradiction that no
amount of re-reading the skill had surfaced.

### Still not covered

`dev-agent` and `code-review-agent` have run only inside an orchestrator's
workflow (`g02`, `g05`, `g10`), never standalone against a GitLab MR.

## Correction: these runs suppressed delegation, on a false premise

Every prompt in the section above contains a line like *"Sub-agents are not
available here, so do the work yourself."* **That premise was wrong.**
`spawn_agent` is available in `codex exec` with no configuration at all; a
later probe spawned a working sub-agent both with and without the
`[orchestrator]` config block.

Two further claims made earlier in this file's history were also wrong:

| Claimed | Actually |
|---|---|
| Sub-agent depth is capped at 1 | The primary agent is told "those sub-agents can spawn their own sub-agents" |
| Delegation needs enabling | It is on by default; what is gated is *when* the model may use it |

The real constraint is a server-delivered instruction:

> `<multi_agent_mode>` Any earlier instruction enabling proactive multi-agent
> delegation no longer applies. Do not spawn sub-agents unless the user or
> applicable AGENTS.md/skill instructions **explicitly ask** for sub-agents,
> delegation, or parallel agent work.

That is good news for a hub-and-spoke design - a skill that says "Delegate to
`requirements-agent`" is precisely the explicit authorisation being asked for -
but it means delegation has to be stated in the skill text. A skill that only
implies it silently gets one agent doing everything.

What this costs the results above: they remain valid evidence for the
issue-to-merge lifecycle and for the bounded review loop, which is what they
were built to measure. They are **not** evidence about delegation, and they
turned off the mechanism the architecture is built on. The end-to-end campaign
below was run with delegation left on.

### Why the mistake survived so long

`codex exec --json` never surfaces sub-agent activity. A parent waiting on a
productive worker emits exactly this, and nothing else:

```
collab_tool_call  tool=wait  receiver_thread_ids=[]  agents_states={}
```

The underlying call is `wait_agent`; the rendered event drops the name and the
receiver. So a healthy parent supervising a sub-agent is indistinguishable, in
the event stream, from a parent spinning on nothing - and it reads like the
latter. That misreading killed a healthy `kickoff` ten minutes into `e2e-01`.

The reliable signal is the thread count: Codex writes one
`sessions/**/rollout-*.jsonl` per thread, so more than one means real
sub-agents. `run-codex.sh` now records it in `result.json` as `threads` and
`subagents`.


## End to end on a greenfield project: kickoff, plant a bug, replicate, fix

The campaign above tested skills against a seeded app. This one built a product
from a brief, broke it, and drove the break through investigation and repair.
Brief: LabSlots, teaching-lab bench booking with capacity, an ordered waitlist,
overlap rules, a cancellation cut-off and a utilisation report.

```
run     skill              outcome                                     cost
e2e-02  kickoff            requirements 501 lines, architecture 853,   ~19 pts
                           ui-design 727, 8 issues, 8 MRs, all
                           reviewed, 8 review budgets at 1 of 3
e2e-04  replicate-issue    reproduced in a real browser at the          ~0 pts
                           reported scale, named the cause exactly,
                           5 screenshots, changed no product code
e2e-05  bugfix             MR !9 merged, issue #9 closed, 4 regression  1 pt
                           tests, 6 sub-agents, all 6 phases complete
```

`kickoff` never merged anything, so `main` was assembled by hand before the bug
could be planted. See the branch-ancestry defect below.

### The planted regression

One line was pushed straight to `main` as "refactor: simplify waitlist position
query": the `status=WAITLISTED` predicate was dropped from `waitlist_position()`,
so a waiting student is shown a number that counts confirmed and historical
rows. Issue #9 described symptoms only - no file, function or cause.

Baseline before, symptom after, and after the fix, measured the same way each
time from a fresh clone on an isolated compose project:

```
                    baseline    with bug    after fix
join             -> B=1, C=2    B=2, C=3    B=1, C=2
after promotion  -> C=1         C=3         C=1
full suite       -> 24 passed   1 failed    28 passed
```

### What replicate-issue got right, and the one thing it missed

It reproduced at the reported scale - 12 confirmed students, then two waitlist
joins - and captured the wrong strings verbatim from the rendered UI ("You
joined the waitlist at position 13." for the only person waiting). It named the
cause as `waitlist_position()` failing to limit prior rows to
`status=WAITLISTED`, which is exactly the planted diff. It scoped its claims
correctly, reporting capacity, FIFO ordering and promotion as working, which
was true. It rejected a false positive from a fixture collision and reran clean
rather than reporting it. It changed no product code.

**It never ran `pytest`** - zero invocations. The planted commit turned
`test_full_session_adds_fifo_waitlist` red, so the suite was failing throughout
the investigation and the report does not mention it. For a regression, `git
log` plus the test suite is the cheapest route to the answer.

### What bugfix demonstrated that kickoff did not

- **Delegated the implementation** to a worker that "will not merge its own MR".
- **Used the loop key the skill specifies**, `review:mr-9`, where kickoff wrote
  `review:issue-N`.
- **Merged**, and let the merge close the issue.

The fix was the exact inverse of the planted diff, one line, no collateral
edits. Its four regression tests close the coverage gap the *investigation*
report had named - one skill acting on another's finding.

The review verdict was APPROVED with no findings, which is correct for a
one-line fix and is what `code-review-agent` is written to produce. It ran the
suite itself instead of trusting the author and pinned the head SHA it reviewed.


## Hardening the two flows that did not finish

Both defects the greenfield run exposed were instructed by the skills.

`tech-lead-agent` said "delegate to a dev-agent" on line 57 and "keep the graph
one level deep" on line 92. Under `kickoff` the tech lead *is* that one level,
so the cap cancelled the delegation twelve lines above it, and it implemented
all eight issues itself. "Issues with no dependency between them can run at the
same time" is what produced four branches cut from the empty commit.

The cost was the artifacts, not the model tier: 2094 lines of requirements,
architecture and UI design, re-read by every later phase and every worker on
every turn.

Re-tested on a fresh greenfield project, LoanBox, from a one-page brief:

```
                       before (e2e-02)        after (e2e-07)
artifacts                2094 lines             505 lines
issues                   8, filed upfront       5, filed one at a time
dev-agent                never spawned          spawned, TDD against PostgreSQL
branch ancestry          4/8 from empty commit  merge-base == main tip
merged                   0 of 8                 issue #1 merged and closed
loop key                 review:issue-N         review:mr-N, as specified
loop reset after merge   never reached          reset to {}
budget at 47 minutes     ~9% and climbing       29%, flat
```

The bounded loop earned its cost on the first issue: round 1 caught static
assets 404ing in the deployed image, which the unit tests could not see, and
round 2 caught a focus indicator at 2.15:1 against a 3:1 WCAG floor. Both were
fixed test-first with the red test demonstrated, and re-reviewed by a fresh
reviewer at the new head.

`replicate-issue` now runs the project's suite and checks `git log` before
opening a browser:

```
                    before (e2e-04)      after (e2e-06)
duration            602s                 430s
input tokens        2.1M                 1.6M
ran the suite       no (0 invocations)   yes - "1 failed, 27 passed"
named the commit    no                   yes - e96991e, "changed > to >="
```

Faster, cheaper and more accurate together: a failing test beside the commit
that caused it is a shorter path than reconstructing the cause from a browser.

Two lint rules now hold these invariants, and both were checked against a
deliberately broken copy of the tree rather than assumed to work: a skill that
caps sub-agent depth, and a merge-owning skill whose completion bar never
mentions merging.


### kickoff reaching `status: complete`

LoanBox, from a one-page brief to a delivered product, across four sessions
connected only by `.okdev/run-state.json`:

```
phases_done: environment, requirements, architecture, implement, testing, delivery
status:      complete

22 commits on main       7 merge requests, all merged
9 issues: 7 closed, 2 open and named
67/67 tests passing      96.94% statement coverage
verdict: "Ready for internal/pilot use. Not ready for public production
          deployment in the committed local-development configuration."
```

Every feature branch descended from the `main` that existed when it was cut -
checked with `git merge-base --is-ancestor`, not taken from the run's own
report. The two open issues are a missing favicon and some direct unit
assertions; both were left open with a reason rather than quietly closed, and
issues #7 and #8 were raised by the testing phase and then fixed and merged.

Three of the four sessions ended for reasons outside the workflow: a wall-clock
timeout I set too short, an upstream "Selected model is at capacity", and a
harness fault of my own. In each case the next session read `run-state.json`,
resumed at the exact issue and review round, and did not redo a finished phase.
That is the property worth having from a multi-hour autonomous run - not that
one process reaches the end, but that losing one costs only the work in flight.


## Unattended: the supervisor on the complex brief

The brief that produced eight issues, zero merges and 19 points of the weekly
window was re-run against the hardened tree, with `okdev-supervise` driving it
from inside the container - the same path a real install uses.

```
12:27  session 1 ... 13:27  ended (exit 124)   timeout
13:27  session 2 ... 14:27  ended (exit 124)   timeout
14:27  session 3 ... 15:27  ended (exit 124)   timeout
15:27  session 4 ... 16:27  ended (exit 124)   timeout
16:27  session 5 ... 16:47  ended (exit 0)
16:47  workflow complete after 5 session(s)
```

Four consecutive one-hour timeouts, each resumed within a second, carrying the
exact phase and review-loop round across every boundary. No human touched it.

```
                     e2e-02 (before)      e2e-11 (supervised)
issues                 8, filed upfront     5, one at a time
merged                 0 of 8               5 of 5
artifacts              2094 lines           417 lines
cost                   19 points            4 points
sessions               1, died at 46 min    5, all resumed automatically
terminal state         never reached        complete
```

`review:mr-4` is the interesting one: CHANGES REQUESTED with two MUST FIX
findings, a fix pushed, then APPROVED on round **3 of 3** - converging exactly
at its budget rather than overrunning it. The round-3 reviewer verified both
prior findings at `apps/bookings/views.py:103`, ran the full PostgreSQL suite,
pinned the head SHA, and reported no new findings rather than inventing some.

The delivery report says **"NOT READY - delivered for evaluation with known
issues"** and files what it found instead of glossing:

```
#6 Production 404 route exposes Django DEBUG page      security
#7 Technician new-session form overflows on mobile
#8 Admin utilisation results table overflows at 360px
#9 Promotion notification exposes raw session UUID     information disclosure
```

Two of those four are security-adjacent. A run that finishes and says "not
ready, here is why, here are the tickets" is worth more than one that finishes
and says nothing.

## Cost

Around two dozen Codex runs, roughly 7M input tokens, moved the weekly ChatGPT
window by two percentage points (2% at the start of the work, 4% after) - well
inside the 10% budget for the whole task. The
budget guard in `budget.sh` refuses to start a run once the window passes
`OKDEV_BUDGET_CEILING`.

Reasoning tier changes cost far more than it changes outcome on work this size:
Sol at `xhigh` spent 2.7x Terra's input tokens and 2.7x its wall clock to reach
the same verdict.
