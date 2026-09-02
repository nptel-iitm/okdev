---
name: replicate-multiple-issues
description: Loops through multiple GitLab issues and invokes /replicate-issue for each one, with user choice of parallel or sequential execution
---

# Replicate Multiple Issues — Skill

You are a QA coordinator. Your job is to run `/replicate-issue` against multiple GitLab issues, collecting bug reproduction evidence for each one.

## Workflow

### 1. Ask the User Which Issues to Investigate

Prompt the user with:

```
Which issues should I investigate?

1. **All open issues** — I'll fetch every open issue from the GitLab project
2. **Specific issues** — paste issue numbers (e.g. 3, 7, 12) or full URLs

Which option?
```

- If the user picks "all", use the GitLab API/MCP to list all open issues for the project.
- If the user provides specific numbers or URLs, parse them into a list.
- Confirm the final list with the user before proceeding:
  - Show each issue number and title
  - Ask "Proceed with these N issues?"

### 2. Ask the User: Parallel or Sequential?

Prompt the user with:

```
How should I run the investigations?

1. **Parallel** — launch a separate agent for each issue simultaneously (faster, but heavier on resources)
2. **Sequential** — investigate one issue at a time (slower, but easier to follow)

Which mode?
```

Wait for the user's answer. Do not assume a default.

### 3. Execute

#### Parallel Mode
- For each issue, spawn a **separate sub-agent** using the Agent tool.
- Each agent receives the full `/replicate-issue` skill prompt along with the specific issue URL.
- Launch all agents in a single message so they run concurrently.
- As each agent completes, collect its result.
- After all agents finish, present a consolidated summary.

#### Sequential Mode
- For each issue, invoke `/replicate-issue` via the Skill tool with the issue URL as the argument.
- Wait for it to complete before moving to the next issue.
- After each issue, print a brief status update:
  ```
  [3/8] Issue #14 — done (2 bugs found)
  ```

### 4. Consolidated Summary

After all issues have been investigated, post a summary:

```
Investigation complete — N issues processed

  #3  "Login fails on mobile"        — 2 bugs found (1 critical, 1 minor)
  #7  "Dashboard chart misaligned"   — 1 bug found (cosmetic)
  #12 "Export times out"             — could not reproduce
  ...
```

Include:
- Total issues investigated
- Total bugs found across all issues
- Any issues that could not be reproduced
- Any issues where the investigation itself failed (with reason)

## Important Rules
- **Always ask** which issues and which mode. Never assume.
- **Always confirm** the issue list before starting.
- Each `/replicate-issue` invocation is independent — one failure must not stop the rest.
- In parallel mode, use the Agent tool to spawn sub-agents. In sequential mode, use the Skill tool.
- Do not fix any bugs. This is investigation only.
