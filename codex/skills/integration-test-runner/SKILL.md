---
name: integration-test-runner
description: Use when the boundaries between components need testing - API contracts, database operations, service-to-service calls, auth flows, queues, file storage. Writes and runs integration tests against real dependencies in containers and reports results. Not for pure logic (unit tests) or browser flows (E2E).
model: gpt-5.6-terra
effort: medium
---

# Integration test runner

Test the seams. Most production failures happen where two components meet, not
inside either one, so this suite exercises real dependencies rather than mocks.

## Start here

Run `.okdev/bin/okdev-state next`. Continue from the phase recorded in
`.okdev/run-state.json` if one exists.

If there is no run state yet — this skill was invoked directly rather than by an orchestrator — create it:

```
.okdev/bin/okdev-state init --workflow integration-test-runner
```

`init` prints the existing state and changes nothing when a run is already in progress, so it is safe either way.

## Inputs

- The codebase and `.okdev/architecture.md` for the component boundaries.
- The integration section of `.okdev/test-plan.md` if present.

## What to do

Map the boundaries first, from the architecture document and from the code:
frontend to API, API to database, service to service, and every outbound call to
something you do not own. That map is the checklist.

Test each boundary against the real thing. Databases run in a container and get
migrated, not stubbed. API tests start the actual server and make real HTTP
requests. If the project has a `docker-compose.yml`, bringing the stack up and
confirming the services can talk to each other is itself one of the tests.

Cover the contract in both directions: the success response with its exact
shape and status code, and the failure the caller must handle — a 4xx for bad
input, a 5xx path, a constraint violation, a rejected transaction, an expired
token. A boundary tested only on its happy path is untested.

Reserve mocks for third-party services that cost money, mutate real-world state,
or are unavailable in CI. When you mock one, assert against the contract you
believe it has, and say in the report that it was mocked.

Run dependencies through Docker rather than installing them on the host. Give
long suites unbuffered output and a timeout larger than the total expected
runtime including container startup.

## Report

Write `.okdev/test-results/integration-tests.md`:

- counts of total, passed, failed, skipped
- each boundary from the map, the tests covering it, and its status
- boundaries with no coverage, named explicitly
- each failure with its error and the boundary it belongs to
- which dependencies were real and which were mocked

## Done when

Every boundary in the map is either covered by a test that ran, or listed as
uncovered with a reason. `integration-tests.md` reflects an actual run. Then run
`.okdev/bin/okdev-state complete --workflow integration-test-runner`.

## Stop when

Record a blocker with `.okdev/bin/okdev-state block "<reason>"` and end the turn
if Docker is unavailable, or a required dependency cannot be started, and the
fix is outside this repo. Give the command and the error. A suite quietly
converted to mocks because the real dependency would not start is worse than a
recorded blocker, because it reports success for something never tested.
