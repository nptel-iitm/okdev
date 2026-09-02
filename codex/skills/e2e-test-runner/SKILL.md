---
name: e2e-test-runner
description: Use when critical user flows need end-to-end testing through the real UI with Playwright - signup, login, core CRUD, navigation, form validation, error states. Verifies the app is running, writes and runs browser tests, captures screenshots, and reports flow results.
model: gpt-5.6-terra
effort: medium
---

# E2E test runner

Drive the running application through a browser the way a user would, and prove
the critical flows work end to end.

## Start here

Run `.okdev/bin/okdev-state next`. Continue from the phase recorded in
`.okdev/run-state.json` if one exists.

If there is no run state yet — this skill was invoked directly rather than by an orchestrator — create it:

```
.okdev/bin/okdev-state init --workflow e2e-test-runner
```

`init` prints the existing state and changes nothing when a run is already in progress, so it is safe either way.

## Inputs

- A URL where the application is actually running.
- The E2E section of `.okdev/test-plan.md`, or the critical flows from the
  requirements if there is no plan.
- Test credentials, if any flow needs them.

## What to do

Confirm the app responds before writing anything — `curl -sf <url>`. If it does
not, bring the stack up with `docker compose up -d`, then poll for readiness with
a bounded wait rather than a fixed sleep, giving the command a timeout longer
than that wait.

Write one Playwright spec per flow. The flows that always matter: authentication
including any OAuth path, the core create-read-update-delete cycle for the
product's main object, navigation between the main pages, form validation with
both valid and invalid input, and the error states — a bad URL, a failed
request, an empty list.

Assert on what the user sees: visible text, URL, element state. Wait with
Playwright's own locator assertions and load-state helpers, never with a fixed
`waitForTimeout`, which is the main source of flaky suites.

Configure the run with `screenshot: 'on'` and `trace: 'on-first-retry'` so every
result carries evidence, and point the output at
`.okdev/test-results/screenshots/e2e/`.

Run the suite. When a flow fails, capture what the page actually showed and
compare it to what the flow expected. Distinguish a real product bug from a
brittle selector, and fix the selector while leaving the product bug failing and
reported.

## Report

Write `.okdev/test-results/e2e-tests.md`:

- flows attempted, passed, failed
- per flow: the steps exercised, the result, and the screenshot path
- per failure: expected versus actual, the screenshot, and whether you judged it
  a product bug or a test defect
- flows in the plan that you could not run, and what stopped them

## Done when

Every planned flow has run or is listed as unrunnable with a reason, screenshots
exist for the results, and `e2e-tests.md` reflects the real run. Then run
`.okdev/bin/okdev-state complete --workflow e2e-test-runner`.

## Stop when

Record a blocker with `.okdev/bin/okdev-state block "<reason>"` and end the turn
if the application will not start, or a flow needs credentials that were not
supplied. Do not fabricate a login by injecting cookies or tokens to get past a
sign-in screen — that reports a passing flow no user could complete.
