# Codex harness

Runs an OKDev skill under the real Codex CLI, inside Docker, and scores what it
did. Built to answer one question: does a skill finish, or does it grind?

Results and the experiment behind the Codex skill tree are in
[RESULTS.md](RESULTS.md).

## Layout

```
Dockerfile          node:22 + codex CLI (pinned) + git, rg, python, pytest
budget.sh           reads the ChatGPT weekly window; refuses to overspend
run-codex.sh        runs one skill against one fixture, records everything
score.py            scores a finished run against a fixture's expect.json
lint-skills.py      free structural checks on a skill tree
check-catalog.sh    free check that skills register, as the model will see them
fixtures/<name>/    repo/ + prompt.txt + expect.json
```

Bulk artifacts live outside the repo, under `$OKDEV_LAB`
(default `/run/media/rishav/data/okdev-codex-lab`).

## The free checks

Run these before spending anything. Neither makes a model call.

```
python3 tests/codex-harness/lint-skills.py codex/skills
bash    tests/codex-harness/check-catalog.sh codex/skills
```

`lint-skills.py` enforces the properties the Codex tree depends on: durable run
state, a stated completion bar, no loop whose only exit is a human, no spawn
chain deeper than one level, and no delegated skill reading. Pointed at
`claude/skills` it reports 110 errors, which is the size of the gap between the
two contracts.

`check-catalog.sh` renders the prompt Codex will actually send and confirms
every skill appears in it. Codex shows the model only a skill's name,
description and path — never the body — so a weak description means the skill
can never be selected no matter how good its instructions are.

## Running a skill

```
docker build -t okdev-codex-test:0.145.0 tests/codex-harness

bash tests/codex-harness/run-codex.sh \
  --run-id my-run \
  --prompt-file tests/codex-harness/fixtures/unit-tests-basic/prompt.txt \
  --fixture    tests/codex-harness/fixtures/unit-tests-basic/repo \
  --model gpt-5.6-terra --effort medium

python3 tests/codex-harness/score.py \
  "$OKDEV_LAB/runs/my-run" \
  tests/codex-harness/fixtures/unit-tests-basic/expect.json
```

Each run gets a private `CODEX_HOME`, so sessions, state and skills never leak
between runs. `auth.json` is copied rather than mounted, so a token refresh
inside the container cannot corrupt your credentials.

Useful flags:

- `--skills <dir>` — which tree to install. Use `claude/skills` for a control.
- `--runtime claude|codex|none` — which runtime to install alongside it.
  **A control run needs `--runtime claude`.** Leaving it on `codex` drops
  `codex/AGENTS.md` into the workspace and hands the old skills the new
  operating rules, which silently invalidates the comparison. That mistake
  invalidated the first attempt at the experiment in RESULTS.md.
- `--reuse-work <dir>` — start from an existing workspace instead of a fixture.
  A fresh session over a used workspace is compaction taken to its limit: no
  conversational memory, so only state written to disk survives. This is how
  the resumption tests work.
- `--compact-at <tokens>` — force auto-compaction past a token count.
- `--no-network` — cut the container off. Codex needs the network to reach the
  API, so this is only for testing how a skill behaves when its dependencies
  are unreachable.

## Budget

`run-codex.sh` calls `budget.sh check` before every run and refuses to start
once the weekly window reaches `OKDEV_BUDGET_CEILING` (default 12).

```
bash tests/codex-harness/budget.sh used    # integer percent of the weekly window
bash tests/codex-harness/budget.sh json    # the full payload
```

The ceiling is an absolute percentage of the window, not a delta, so set it to
`current + what you are willing to spend` before a campaign.

For scale: the entire campaign in RESULTS.md — around two dozen runs and
several million input tokens — moved the window by under one percentage point
on a Pro plan.

## Writing a fixture

A fixture is a directory with `repo/` (the starting project), `prompt.txt`
(what the agent is told) and `expect.json` (machine-checkable expectations —
see the docstring in `score.py` for the fields).

Two things are easy to get wrong, and both produce a test that passes for the
wrong reason:

**Do not leak the answer.** When testing whether a skill recovers state from
disk, make sure nothing else carries it — not a counter file inside the
workspace, not a round number in a tool's output, not a sentence in the prompt.
All three leaked in the first version of the resumption test, and each one made
the control look correct.

**Commands run under `pipefail`.** A `cmd | tail -1` assertion would otherwise
report `tail`'s exit status and pass no matter what `cmd` did — one of these
slipped through and scored a run green while `pytest` was not even installed.
The flip side is that `git log | grep -q` now dies of SIGPIPE, so write
assertions without pipes where you can.

**Prefer a fixture that can fail.** A test where the desired behaviour is also
the path of least resistance proves very little. The review-loop fixtures use a
reviewer that can never be satisfied precisely so that stopping requires the
skill's budget to work.
