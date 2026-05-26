---
name: manual-suite-driver
description: Drives a codebase to a state where an entire manual test suite passes. For each manual test-case file, runs it in a browser via Playwright MCP, files GitLab issues for any bugs, fixes them through /replicate-and-kickoff, and re-runs until green — then runs the full suite as a regression gate and repeats until every test passes. Every testing session runs in an isolated sub-agent. Designed to be driven by the built-in /goal feature (e.g. "/goal run the manual-suite-driver skill against tests/manual/").
user_invocable: true
---

# Manual Suite Driver

You are a goal-driven test-and-fix orchestrator. Your **end goal** is to bring the
codebase to a state where the **entire manual test suite passes**. You get there in
two stages:

1. **Per-test fix loop** — take each manual test-case file one at a time, run it,
   fix every bug it surfaces, and re-run until that single test passes.
2. **Full-suite regression loop** — once every test passes individually, run the
   whole suite together to catch fixes that broke other tests, fix those, and re-run
   the whole suite until everything is green at once.

Invocation notes:
- In Claude Code, start this skill with `/manual-suite-driver`, or drive it through the
  built-in `/goal` feature (e.g. `/goal run the manual-suite-driver skill against
  tests/manual/`). Do NOT name this skill `goal` — that collides with the built-in
  `/goal` command.
- In Codex, invoke the same skill as `$manual-suite-driver`.

## Core Principles (read first)

- **Manual tests run via Playwright MCP — NEVER scripts.** Every test is executed in
  a real browser through the Playwright MCP tools (`browser_navigate`, `browser_click`,
  `browser_type`, `browser_snapshot`, etc.), behaving like a real user. Do NOT write or
  run Playwright/pytest test scripts, curl, or any automated harness to "run" a manual
  test. No spoofing, no API shortcuts, no bypassing login.
- **Every testing session is an isolated sub-agent.** Each test run (single test or
  full suite) happens inside a fresh sub-agent spawned via the **Agent tool**. The
  sub-agent does the browser work and returns only a terse summary (PASS/FAIL + bug
  list + filed issue numbers). The heavy context — snapshots, console logs, DOM dumps —
  never enters your context. This is compaction-equivalent isolation; your parent loop
  stays light no matter how many tests or iterations run.
- **Bug handoff is GitLab-issue-first.** When a test fails, the bug is filed as a
  GitLab issue (with reproduction evidence), then fixed by running
  `/replicate-and-kickoff` against that issue in its own sub-agent.
- **No shortcuts when blocked.** If infrastructure is missing or a loop stalls, STOP
  and ask the user (see Loop Guards). Never declare a test "passing" without actually
  running it green in the browser.

## Inputs

- **A directory of manual test-case files** the user points to (e.g. `tests/manual/`,
  `*.md` files each describing one manual test case in plain-language steps). If not
  provided, ask the user for the path.
- **A running application URL** to test against. Playwright MCP needs a live app.

## Phase 0: Setup & Discovery

1. **Get the test directory.** Use the path the user provided, or ask for it. Discover
   every test-case file in it (e.g. all `*.md` / `*.txt` files, one manual test case
   per file). Sort them into a stable order.
2. **Confirm the app is running.** Ask the user for the application URL (or confirm the
   one they gave). If the app is not up, STOP and ask the user to start it — do not try
   to boot it yourself unless the user asks.
3. **Confirm GitLab is reachable** (issues will be filed here) — the GitLab MCP must be
   configured. If not, STOP and tell the user.
4. **Show the discovered test list** (file name + one-line intent each) and confirm:
   `Found N manual test files in <dir>. Drive the codebase until all N pass — proceed?`
   Wait for confirmation before starting.

Record the test directory, app URL, and discovered file list so later phases reference them.

## Phase 1: Per-Test Fix Loop

Process test files **one at a time, in order**. Do NOT move to the next file until the
current one passes (or the user tells you to skip it).

For each test file `T`:

1. Print a header: `[i/N] <T> — starting`
2. **Iterate** (a single fix cycle):

   **a. Run the test (isolated sub-agent).** Spawn a fresh sub-agent via the **Agent
   tool**. Instruct it to:
   - Execute the manual test case described in file `T` against the app URL, using
     **Playwright MCP only**, as a real user following the steps exactly.
   - Take snapshots/screenshots at major steps; watch for console errors, failed
     requests, broken UI, and any deviation from the expected result in `T`.
   - For **each bug found**, file a **GitLab issue** with: clear title, the test file
     it came from, exact reproduction steps, expected vs. actual, and evidence
     (screenshots/console/network).
   - Return ONLY a terse summary: `PASS`, or `FAIL` plus the list of filed issue
     numbers with one-line titles. No transcripts, no snapshots.

   **b. Branch on the result:**
   - **PASS** → record `T` as passing and break out of the iterate loop; go to the
     next test file.
   - **FAIL** → for each filed issue, run `/replicate-and-kickoff` to fix it:
     - Spawn a **fresh Agent sub-agent** whose prompt instructs it to execute the
       `/replicate-and-kickoff` skill against the issue URL (reproduce + drive the fix
       through the full SDLC to a merged MR). It returns a one-line outcome.
     - If there are multiple issues, fix them **sequentially** (one fully fixed before
       the next), or delegate the batch to a single sub-agent running
       `/replicate-and-kickoff-multi`. Either way, isolate it in a sub-agent.
   - After the fix(es) merge, **loop back to step (a)** and re-run `T` from scratch in
     a new sub-agent.

3. Repeat (a)→(b) until `T` passes. Print `[i/N] <T> — PASS after K iteration(s)`.

**Why re-run the whole test each iteration:** a fix may resolve one bug but reveal or
introduce another. The test only counts as passing when a clean end-to-end run goes
green with no new bugs.

## Phase 2: Full-Suite Regression Loop

Once **every** test file has passed individually, verify they all still pass *together*
— a fix for one test may have broken another.

Iterate:

1. **Run the entire suite (isolated sub-agent).** Spawn a fresh sub-agent via the
   **Agent tool** instructed to run **all** test files in `<dir>` in sequence against
   the app URL using **Playwright MCP only**, as a real user. For each failing test it
   files a GitLab issue (as in Phase 1a). It returns a terse per-test PASS/FAIL table
   plus the list of any newly filed issue numbers.
2. **Branch:**
   - **All pass** → the end goal is met. Go to Phase 3.
   - **Any fail** → if the regression round limit (5 rounds) is reached, STOP and report which tests remain red. Otherwise, fix every newly filed issue via /replicate-and-kickoff in isolated sub-agents (same handoff as Phase 1b), then loop back to step 1 and re-run the entire suite.

Repeat until a single full-suite run is fully green.

## Phase 3: Final Report

Print a concise summary to the user:

```
Goal: manual suite passing — <ACHIEVED / STOPPED>

Tests: N total
  ✓ login.md            — passed (2 fix iterations, issues #41, #43)
  ✓ checkout.md         — passed (1 fix iteration, issue #45)
  ✓ profile-edit.md     — passed (0 fixes, green first run)
  ...

Full-suite regression: <green on pass M / stopped>
  Round 1: 1 regression (issue #52) — fixed
  Round 2: all green

Issues filed: X   MRs merged: Y
```

Include: total tests, per-test outcome and fix count, regression rounds, all GitLab
issues filed and their fix status, and a clear final statement of whether the entire
manual suite now passes.

## Loop Guards (avoid infinite loops)

- Cap fixes per single test at **5 iterations**. If a test still fails after 5
  fix cycles — or if two consecutive iterations surface the *same* bug with no
  progress — STOP and ask the user how to proceed. Do not keep grinding.
- Cap the full-suite regression at **5 rounds**. If it still isn't green, STOP and
  report which tests remain red and why.
- If a `/replicate-and-kickoff` run reports it could not reproduce or could not fix the
  issue, STOP and surface that to the user before re-running the test.
- A failure to fix one bug must not silently mark a test as passing. The only way a
  test is "passing" is a clean green browser run.

## Important Rules

- **Playwright MCP for every manual-test run — never scripts.** This is the single
  most important rule. If Playwright MCP is unavailable, STOP and ask the user.
- **One isolated sub-agent per testing session** (single test run and full-suite run
  alike). Never run the browser steps in your own context. Return only terse summaries.
- **Do NOT invoke `/replicate-and-kickoff` or `/replicate-and-kickoff-multi` directly
  via the Skill tool from this skill** — that would pull their full output into your
  context. Always run them inside an Agent sub-agent.
- **Sequential, not parallel**, in Phase 1: finish one test file (passing) before the
  next. Bugs within a test are fixed before the test is re-run.
- Keep your own output terse — the heavy lifting lives inside the sub-agents and in
  GitLab. Detailed evidence lives on the issues, not in your messages.
- If blocked (app down, GitLab unreachable, Playwright MCP missing, loop guard tripped),
  STOP and ask the user. Never silently degrade quality.
