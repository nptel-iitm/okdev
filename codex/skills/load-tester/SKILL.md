---
name: load-tester
description: Use when an application's performance under load needs measuring - throughput, p95 and p99 latency, error rate at concurrency. Runs k6 via Docker against performance-critical endpoints and reports results against thresholds. Run only after functional tests pass.
model: gpt-5.6-luna
effort: medium
---

# Load tester

Measure how the application behaves under concurrency, and say plainly whether
it meets its thresholds.

## Start here

Run `.okdev/bin/okdev-state next`. Continue from the phase recorded in
`.okdev/run-state.json` if one exists.

If there is no run state yet — this skill was invoked directly rather than by an orchestrator — create it:

```
.okdev/bin/okdev-state init --workflow load-tester
```

`init` prints the existing state and changes nothing when a run is already in progress, so it is safe either way.

## Inputs

- A URL where the application is running.
- Performance thresholds, defaulting to: p95 under 500ms, p99 under 1000ms,
  error rate under 1%, sustained throughput of at least 50 requests per second.
- The endpoints worth measuring — the ones on the critical path, not every route.

## What to do

Run k6 from the `grafana/k6` Docker image rather than installing it.

Write one script per endpoint group, with a stage profile that ramps up, holds a
sustained load, pushes to a peak, and ramps down, so the numbers show behaviour
under sustained pressure rather than a single burst. Encode the thresholds in
the script's `thresholds` block so k6 itself decides pass or fail.

Run with the results written to JSON so the report quotes measured numbers:

```
stdbuf -oL docker run --rm --network host -v "$PWD:/scripts" grafana/k6 \
  run --out json=/scripts/results.json /scripts/load-test.js
```

Set the command timeout above the total stage duration — a 150 second profile
needs at least 180 seconds — because a load test killed early produces numbers
that look like a failure but mean nothing.

Point load only at services this project owns. Third-party endpoints are out of
scope regardless of what the flow calls.

When a threshold is missed, report the measurement and what the shape of the
data suggests — latency climbing with concurrency points somewhere different
than a flat error rate from the start. Diagnosis here is reporting, not a
mandate to go optimise the code.

## Report

Write `.okdev/test-results/load-tests.md`:

- each threshold, the measured value, and pass or fail
- per endpoint: average, p95, p99, throughput, error count
- the stage profile actually used and the total duration
- endpoints that missed a threshold, with what the data suggests
- anything that could not be measured, and why

## Done when

Every in-scope endpoint has measured numbers or a stated reason it has none, and
`load-tests.md` quotes the real k6 output. Then run
`.okdev/bin/okdev-state complete --workflow load-tester`.

Missed thresholds are a valid, complete result. Report them.

## Stop when

Record a blocker with `.okdev/bin/okdev-state block "<reason>"` and end the turn
if the application is not reachable, or Docker cannot run the k6 image. Do not
substitute a hand-rolled loop of curl calls for k6; the percentiles it produces
are not comparable and would make the report misleading.
