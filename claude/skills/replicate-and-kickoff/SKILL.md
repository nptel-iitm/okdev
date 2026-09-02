---
name: replicate-and-kickoff
description: For a single GitLab issue, first runs /replicate-issue to reproduce and document the bug, then runs /kickoff to drive the fix through the full SDLC. Each phase runs in an isolated sub-agent to prevent context spillover.
---

# Replicate and Kickoff — Skill

You are a coordinator. For a single GitLab issue, you run two phases back-to-back:
1. **Replicate** — reproduce the bug and post evidence to the issue (`/replicate-issue`)
2. **Kickoff** — drive the fix through the full development lifecycle (`/kickoff`)

Each phase MUST run inside its own sub-agent (via the Agent tool) so that the large
context produced by one phase does not spill into the other or into your own context.

## Inputs

- A single GitLab issue URL or issue number. If not provided, ask the user for it.

## Workflow

### 1. Confirm the Issue

Show the user the issue you're about to process (number + title) and confirm before proceeding.

### 2. Phase 1 — Replicate (isolated sub-agent)

Use the **Agent tool** to spawn a sub-agent. Instruct it to execute the `/replicate-issue`
skill against the given issue URL. The sub-agent should:
- Run the full replicate-issue workflow
- Post the reproduction report back to the GitLab issue
- Return a short summary (bugs found, reproducible y/n, link to posted report)

Wait for the sub-agent to finish. Capture its summary.

If the bug could not be reproduced, surface that to the user and **ask** whether to
still proceed to kickoff or stop. Do not assume.

### 3. Phase 2 — Kickoff (isolated sub-agent)

Use the **Agent tool** to spawn a **fresh** sub-agent (do not reuse the replicate one).
Instruct it to execute the `/kickoff` skill, using the GitLab issue (now enriched with
the replication report) as the source of requirements. The sub-agent should:
- Run the full kickoff orchestration (requirements → architecture → tickets → dev → test → delivery)
- Return a short final summary (MR links, test results, delivery status)

Wait for it to finish. Capture its summary.

### 4. Final Report

Print a concise two-section summary to the user:

```
Issue #N — "title"

Replication:
  - <one-line outcome, link to report>

Kickoff:
  - <one-line outcome, MR/delivery links>
```

## Important Rules

- **Always use the Agent tool** for both phases. Never invoke `/replicate-issue` or
  `/kickoff` directly via the Skill tool from this skill — that would pollute your
  own context with their full output.
- **Two separate sub-agents.** Do not run both phases inside one sub-agent.
- **Sequential, not parallel.** Replicate must finish before kickoff begins, because
  kickoff depends on the replication report attached to the issue.
- If replicate fails or cannot reproduce, stop and ask the user before kicking off.
- Keep your own output terse — the heavy lifting lives inside the sub-agents.
