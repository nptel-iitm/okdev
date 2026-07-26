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

### Not covered

The skills that need a live browser, a running application or GitLab were
exercised only on their blocking path: `integration-test-runner`,
`load-tester`, `ui-screenshot-scorer`, `manual-spot-checker`, `replicate-issue`,
and the `replicate-*` and `kickoff-multi` coordinators. Their happy paths need a
real project with its stack up.

## Cost

Around two dozen Codex runs, roughly 7M input tokens, moved the weekly ChatGPT
window by two percentage points (2% at the start of the work, 4% after) - well
inside the 10% budget for the whole task. The
budget guard in `budget.sh` refuses to start a run once the window passes
`OKDEV_BUDGET_CEILING`.

Reasoning tier changes cost far more than it changes outcome on work this size:
Sol at `xhigh` spent 2.7x Terra's input tokens and 2.7x its wall clock to reach
the same verdict.
