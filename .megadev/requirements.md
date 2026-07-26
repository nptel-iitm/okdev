# Bug Requirements

## Project

MegaDev / `iitmbsc-student-projects/claude-ecosystem`

## Date

2026-07-20

## Source

Read-only GitLab issue [`agentforge/rearchitect-plan-rishav#313`](http://gitlab.local:8929/agentforge/rearchitect-plan-rishav/-/issues/313).

The issue is evidence only. All implementation tracking, branch work, review, and delivery for this fix belong in the current GitHub repository.

## 1. Overview

Fix MegaDev's merge orchestration so that a green source branch and an approved code review are not sufficient to merge. Immediately before merging, MegaDev must run the project's full suite against the **current proposed merge result**—the source branch combined with the current target branch—not merely against the source branch tip.

If either side changes, the earlier result is stale. A failed combined-tree run must return the issue to development and review rather than merge. After a successful merge, the same full suite must run on the exact resulting target-branch commit as a backstop before delivery is declared successful.

This repository is the orchestration/skill source of truth. This change must update that orchestration; it must not expand into unrelated GitHub Actions, branch-protection, ruleset, notification, or application-CI work in this repository.

For this implementation only, the final GitHub PR must remain open and unmerged until the user performs an additional manual review and explicitly authorizes merging.

## 2. Expected and Actual Behavior

### Expected

1. MegaDev identifies the current source SHA and target SHA before merge validation.
2. It creates or obtains a combined-tree candidate representing those exact revisions.
3. It runs the project's full test suite against that candidate.
4. A failure blocks merging and returns the change to the repair, test, and fresh-review loop.
5. A source or target change invalidates the previous validation and requires a new combined-tree run.
6. Only a successful, current combined-tree run permits the existing merge step to continue.
7. After merging, MegaDev runs the full suite on the exact resulting target-branch commit and blocks delivery on failure.

### Actual

The current instructions enforce branch-tip tests and fresh re-review, but then merge directly after an `APPROVED` verdict without testing the combined tree:

- `CLAUDE.md` says tests must pass before merge but does not identify the commit that must be tested.
- `.claude/skills/tech-lead-agent/SKILL.md` runs the suite on the updated source branch and defines `APPROVED → merge`.
- `.claude/skills/kickoff/SKILL.md` and `.claude/skills/bugfix/SKILL.md` repeat that flow.
- Supporting developer, reviewer, and delivery instructions do not define merge-result failure handling or a post-merge target-branch test backstop.

Consequently, two individually green sibling branches can merge without a textual conflict while their combined tree is broken and untested.

## 3. Reproduction and Historical Evidence

Issue 313 documents this real topology:

1. A shared base contains a scalar `role` attribute.
2. Branch A renames `role` to tuple-valued `roles` and updates every reference visible on A.
3. Sibling branch B adds a new guard reading `self.role`.
4. Each branch independently passes its tests.
5. Combining B with a target containing A produces no textual conflict, but the merged tree defines `roles` and reads `self.role`.
6. The existing suite fails on the combined tree.

The cited historical commits are:

- `6c6fce2`: added the stale `self.role` reference on one sibling branch.
- `1b59109`: renamed `role` to `roles` on another sibling branch.
- `20f282f`: cleanly combined the changes.
- Related issue #289 / MR !224 recorded 42 real failures on merged `main`.

This demonstrates that the fault is not missing test coverage. The tests were run against the wrong commits.

Regression coverage in this repository must model this topology in an isolated temporary Git fixture. It must not alter the read-only GitLab project or its history.

## 4. Functional Requirements

### 4.1 Authoritative pre-merge gate

1. The authoritative tech-lead merge flow must require a successful full-suite run against the current proposed merge result.
2. The gate must record or verify the source SHA, target SHA, candidate merge SHA/tree, test command, and outcome.
3. A source-branch pipeline or source-branch local run is supporting evidence only; it cannot replace the combined-tree gate.
4. For GitLab projects with merged-result MR pipelines, MegaDev may use a successful current `merged_result` pipeline as the candidate-tree evidence.
5. Where the documented orchestration performs local integration validation, it must create an isolated candidate from the exact source and target revisions and run the full suite there without mutating the real target branch.
6. If MegaDev cannot obtain or create the candidate, identify the canonical full-suite command, or verify revision freshness, it must stop and ask the user rather than merge from branch-tip evidence.

### 4.2 Freshness

1. Validation evidence is valid only for its recorded source and target revisions.
2. Any source or target update requires a new candidate and full-suite run.
3. The merge operation must recheck that the revisions still match immediately before proceeding.

### 4.3 Review-loop integration

1. Preserve the current loop: fresh review, address all MUST FIX findings, run the full branch suite, and request another fresh review.
2. After current review approval, run the combined-tree gate before merge.
3. If combined-tree tests fail, prohibit merging, send the failure to development, repair it, rerun branch tests, and obtain a fresh review before trying the gate again.
4. Continue to stop and escalate after three non-converging review rounds.

### 4.4 Post-merge target-branch backstop

1. After an authorized/normal MegaDev merge, run the full suite on the exact resulting target-branch commit.
2. A failure blocks delivery, reports the failed commit and test evidence to the active human operator, and is treated as a release-blocking regression.
3. Delivery cannot report success merely because the MR was merged.

### 4.5 This implementation's hold point

1. Create the implementation branch and GitHub PR in `iitmbsc-student-projects/claude-ecosystem`.
2. Complete automated review and testing, but do not merge the PR.
3. Report the PR as ready for the user's additional manual review and wait for explicit merge authorization.
4. This is a run-specific delivery constraint, not a new universal ban on autonomous MegaDev merges.

## 5. Affected Components

The implementation must inspect and update the smallest consistent set among:

1. `CLAUDE.md` — define that "tests pass before merge" means the current combined tree, plus a target-branch backstop.
2. `.claude/skills/tech-lead-agent/SKILL.md` — authoritative candidate-merge validation, freshness checks, failure loop, merge, and post-merge test.
3. `.claude/skills/kickoff/SKILL.md` — use the authoritative gate in Phase 5 and target-branch backstop before successful delivery.
4. `.claude/skills/bugfix/SKILL.md` — use the same gate while preserving bug-regression coverage.
5. `.claude/skills/dev-agent/SKILL.md` — define developer handling of candidate-merge failures if required for consistency.
6. `.claude/skills/code-review-agent/SKILL.md` — ensure review approval is not represented as proof that the combined tree passes, if required for consistency.
7. `.claude/skills/delivery-agent/SKILL.md` — require successful post-merge target-branch validation before delivery success.
8. Repository-native tests or validation scripts — verify instruction consistency and reproduce the historical semantic merge collision.

Do not modify unrelated skills or add general repository CI infrastructure unless an executable test strictly requires a small repository-native helper.

## 6. Non-Functional Requirements

1. **Correctness:** Fail closed when candidate-tree identity, freshness, or tests cannot be verified.
2. **Isolation:** Candidate validation must not mutate the real target branch or overwrite a contributor's workspace.
3. **Traceability:** Record exact revisions and commands so the tested tree is auditable.
4. **Consistency:** All orchestration entry points must agree with the authoritative tech-lead flow.
5. **No shortcuts:** Missing merge-result infrastructure or test commands is a blocker to surface, not a reason to fall back silently to branch-tip tests.
6. **Scope control:** Preserve the existing GitLab-centric downstream workflow and avoid unrelated GitHub CI administration in this repository.

## 7. Technical Constraints

1. The source GitLab issue, project, MRs, pipelines, branches, and commits are strictly read-only.
2. Implementation and tracking occur in the current GitHub repository.
3. Use the target project's existing canonical full-suite command; do not invent a reduced substitute and call it the full suite.
4. Use GitLab's current merged-result pipeline when configured, or a correctly isolated local candidate-merge validation explicitly supported by the orchestration.
5. Do not install tools globally. Follow repository Docker and unbuffered-output rules.
6. The final implementation PR remains open pending the user's manual review.

## 8. UI/UX Requirements

No application UI is affected. Browser screenshots and visual scoring are not applicable.

Operational output must clearly distinguish:

- source-branch tests;
- candidate merge-result tests;
- post-merge target-branch tests;
- stale or unverifiable evidence;
- merge-ready versus delivery-complete states.

## 9. Testing Requirements

### 9.1 Historical semantic-collision regression

Use an isolated temporary Git repository to:

1. create the common base and two sibling changes;
2. prove both isolated branches pass;
3. prove their clean combined result fails behavioral tests;
4. apply the correction and prove the combined result passes;
5. avoid modifying the real repository branches or remotes.

### 9.2 Instruction consistency audit

Verify that affected instructions consistently require:

1. current source+target validation before merge;
2. invalidation after either SHA changes;
3. failure returning to development/review;
4. post-merge target-branch full-suite validation;
5. no remaining `APPROVED → merge` shortcut that bypasses the combined-tree gate.

### 9.3 Workflow walkthrough

Exercise the documented flow in a controlled fixture:

1. branch approval alone cannot satisfy the merge gate;
2. a broken candidate result blocks merge;
3. repaired code must pass branch tests, fresh review, and a fresh candidate run;
4. stale source/target evidence is rejected;
5. post-merge failure blocks delivery.

### 9.4 Scope verification

1. No source GitLab resource is modified.
2. No unrelated GitHub Actions, branch-protection, ruleset, or alerting work is introduced.
3. The implementation GitHub PR remains open and unmerged.

Application integration, browser E2E, screenshot scoring, and load testing are inapplicable because this is an orchestration-documentation and regression-fixture change, not a service or UI change.

## 10. Acceptance Criteria

- [ ] A branch-tip-green but candidate-merge-red change is never merged by MegaDev.
- [ ] The authoritative merge flow tests the current source+target combined tree with the full suite.
- [ ] Exact source and target revisions are captured and rechecked before merge.
- [ ] Any source or target change invalidates earlier candidate evidence.
- [ ] A candidate failure returns work to development, branch testing, and fresh review.
- [ ] Kickoff and bugfix use the same authoritative gate.
- [ ] Supporting developer, reviewer, and delivery guidance is consistent with that gate.
- [ ] The exact resulting target-branch commit receives a post-merge full-suite backstop before delivery succeeds.
- [ ] The historical sibling-branch semantic collision is reproduced by an isolated, non-vacuous regression fixture.
- [ ] No unrelated general GitHub CI infrastructure is added.
- [ ] The final GitHub implementation PR is created but remains unmerged for the user's additional manual review.

## 11. Assumptions and Resolved Defaults

1. MegaDev-managed application projects are GitLab-centric as documented in `CLAUDE.md`.
2. A current successful GitLab merged-result MR pipeline is authoritative when available.
3. A deliberately constructed isolated candidate-merge test is also valid when the orchestration defines and verifies it explicitly; source-branch-only testing is never valid evidence.
4. If neither mechanism is available, MegaDev stops and asks the user.
5. Each managed project must expose a canonical full-suite command before MegaDev can merge it.
6. The user's additional manual-review checkpoint applies to this implementation PR.

No unresolved product ambiguity blocks implementation.
