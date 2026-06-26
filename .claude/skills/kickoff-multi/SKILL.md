---
name: kickoff-multi
description: Loops through multiple GitLab issues and runs /kickoff sequentially against each one — fully replicate-then-fix one issue before moving to the next.
---

# Replicate and Kickoff Multi — Skill

You are a coordinator. For a list of GitLab issues, you run `/kickoff`
against each one **sequentially**. Each issue is fully replicated AND fixed before
the next issue begins. Do NOT replicate all issues first and then kickoff all of them.

## Workflow

### 1. Ask the User Which Issues to Process

Prompt the user with:

```
Which issues should I replicate and fix?

1. **All open issues** — I'll fetch every open issue from the GitLab project
2. **Specific issues** — paste issue numbers (e.g. 3, 7, 12) or full URLs

Which option?
```

- If "all", use the GitLab MCP to list every open issue.
- If specific, parse the numbers/URLs into a list.
- Confirm the final list (number + title for each) and ask "Proceed with these N issues?"
  before starting.

### 2. Execute Sequentially (one isolated sub-agent per issue)

For each issue, in order:

1. Print a header: `[i/N] Issue #X — "title" — starting`
2. Spawn a **fresh top-level sub-agent via the Agent tool** for this single issue.
   - The sub-agent's prompt instructs it to execute the `/kickoff`
     skill against the given issue URL, running both phases to completion.
   - The sub-agent must return **only a single one-line summary** (e.g.
     `replicated; MR !42 merged` or `could not reproduce; skipped kickoff`).
     All detailed reporting already lives in GitLab — do not ask for more.
3. Wait for the sub-agent to finish before spawning the next one.
4. Print a one-line status: `[i/N] Issue #X — <one-line summary>`

**Why a fresh sub-agent per issue:** this gives compaction-equivalent isolation.
None of the per-issue context (replication evidence, kickoff orchestration, dev
output, test results) ever enters the parent loop's context — only the one-line
summary does. The parent stays light no matter how many issues are processed.

**Strictly sequential.** Never start issue i+1 until issue i's sub-agent has fully
returned. Never spawn multiple issue sub-agents in parallel. Never batch the phases
across issues.

A failure on one issue must NOT stop the rest — log it and continue to the next.

### 3. Final Consolidated Summary

After all issues are processed, print:

```
Replicate-and-kickoff complete — N issues processed

  #3  "Login fails on mobile"      — replicated, MR !42 merged
  #7  "Dashboard misaligned"       — replicated, MR !43 in review
  #12 "Export times out"           — could not reproduce, skipped kickoff
  ...
```

Include:
- Total issues processed
- Successes vs failures
- Any issues skipped (and why)

## Important Rules

- **Always ask** which issues. Never assume.
- **Always confirm** the list before starting.
- **Strictly sequential per issue** — replicate-then-kickoff fully, then next issue.
- **One fresh Agent sub-agent per issue.** Do NOT invoke `/kickoff`
  directly via the Skill tool from this skill — that would pull all of its output
  into the parent context. The sub-agent runs the skill on your behalf and returns
  only a one-line summary.
- One issue's failure does not stop the rest.
