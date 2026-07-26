## Source

Read-only upstream report: [GitLab issue agentforge/rearchitect-plan-rishav#313](http://gitlab.local:8929/agentforge/rearchitect-plan-rishav/-/issues/313)

The source issue is filed in a different project. This issue tracks the fix to MegaDev's orchestration in this repository.

## Problem

MegaDev currently runs tests against an updated source branch and merges after a fresh `APPROVED` review. It does not require the full suite to pass against the current **combined source+target tree**. Two individually green sibling branches can therefore merge cleanly while their combined tree is broken and has never been tested.

This is a wrong-commit problem, not a coverage problem: the historical incident already had 42 tests that failed on merged `main`.

## Required behavior

- Before merge, identify the exact current source and target revisions.
- Obtain a current merged-result pipeline or create an isolated candidate merge from those revisions.
- Run the project's canonical full suite against that candidate.
- Fail closed if candidate identity, freshness, or tests cannot be verified.
- Return candidate failures to development, branch testing, and fresh review.
- Invalidate evidence whenever source or target changes.
- After merge, run the full suite against the exact resulting target-branch commit before delivery succeeds.
- Keep kickoff, bugfix, tech-lead, developer, reviewer, and delivery instructions consistent.

## Scope

This is an orchestration/skill fix. Do not add unrelated GitHub Actions, branch-protection/ruleset, alerting, or application-CI infrastructure to this repository.

## Regression coverage

Add an isolated temporary-Git fixture reproducing the historical sibling-branch semantic collision: each branch passes independently, the clean combined tree fails, and the corrected combined tree passes. Add consistency validation proving no orchestration path bypasses the merge-result gate.

## Acceptance criteria

- [ ] A source-branch-green but candidate-merge-red change is never merged by MegaDev.
- [ ] Exact source and target revisions are captured and rechecked before merge.
- [ ] Source or target changes invalidate prior candidate evidence.
- [ ] Candidate failures return to repair, branch tests, and fresh review.
- [ ] The post-merge target commit receives a full-suite backstop before delivery succeeds.
- [ ] All affected orchestration skills agree with the authoritative flow.
- [ ] The historical semantic collision has isolated, non-vacuous regression coverage.
- [ ] No unrelated general GitHub CI infrastructure is introduced.
- [ ] The implementation PR remains open for additional manual review and explicit merge authorization.

Full local specification: `.megadev/requirements.md` (orchestrator artifact, intentionally not part of the product change unless separately decided).
