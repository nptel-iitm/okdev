# AgentForge — Autonomous AI Development System

## Philosophy
- **No shortcuts.** If a tool or service is unavailable, STOP and ask the user. Never work around missing infrastructure with sub-optimal alternatives.
- **Real software engineering.** Follow the same practices a professional team would: requirements → design → tickets → branches → implementation → tests → code review → merge → deliver.
- **Test everything.** Code coverage is necessary but not sufficient. Test functionality, UI quality, integrations, performance, and user flows.
- **We are a team.** The human is here to help unblock, not to be impressed. Communicate blockers honestly.

## Infrastructure
- **GitLab**: Local instance at `http://gitlab.local:8929` (Docker). All repos, issues, MRs, and boards live here.
- **GitLab API Token**: Stored in `infrastructure/gitlab/.gitlab-token`
- **MCP Servers**: Configured in `.mcp.json` at project root.

## Agent Architecture
This system uses a hub-and-spoke model:
- The **Master Orchestrator** (`/kickoff`) coordinates all phases
- Specialized agents are invoked as Claude Code sub-agents via the Agent tool
- Each agent has a single responsibility and clear inputs/outputs
- Agents communicate through GitLab (issues, MRs, comments) and local files

## Agent Skills Location
All agent skills live in `.claude/skills/<skill-name>/SKILL.md`:
- **Orchestration**: `kickoff`, `requirements-agent`, `architect-agent`
- **Development**: `tech-lead-agent`, `dev-agent`, `code-review-agent`
- **Testing**: `test-planner-agent`, `unit-test-runner`, `integration-test-runner`, `e2e-test-runner`, `ui-screenshot-scorer`, `load-tester`, `manual-spot-checker`
- **Design**: `ui-designer-agent`
- **Delivery**: `delivery-agent`

## Coding Standards
- Write tests for all new code
- Use meaningful commit messages
- Create feature branches, never commit directly to main
- All changes go through MRs with code review
- Follow the language/framework conventions of the project being built

## Testing Standards
- Unit tests: Cover all business logic
- Integration tests: Cover all service interactions
- E2E tests: Playwright for all critical user flows
- UI tests: Screenshot every page, score for quality (threshold: 7/10)
- Load tests: Verify performance under expected load
- Manual spot-checks: 10 random manual test cases as final validation

## GitLab Workflow
1. All work starts as a GitLab issue
2. Issues are organized on a board: Backlog → To Do → In Progress → Review → Testing → Done
3. Each issue gets a feature branch
4. Implementation creates a Merge Request
5. Code review agent reviews the MR
6. Tests must pass before merge
7. Tech lead agent monitors the board and drives completion

## Operational Rules
- **Docker for all installations**: Never install tools directly on the host via pip, npm -g, apt-get, etc. Always use `docker run` with the appropriate image. The host stays clean.
- **Unbuffered output for background commands**: When running any command in the background, always use unbuffered output (`stdbuf -oL`, `PYTHONUNBUFFERED=1`, `python3 -u`, `node --no-warnings` with pipe, etc.) so progress is visible in real time.
- **Timeout must match sleep duration**: When a command includes sleep/wait loops, set the tool timeout to at least the total possible sleep duration. A 300s wait loop needs timeout >= 300000ms.
- **Audio input support**: Requirements may come as audio files. Use Whisper (via Docker: `docker run --rm -v ...:/data openai/whisper ...`) for speech-to-text transcription.

## When Blocked
1. Log the blocker clearly
2. Attempt ONE reasonable alternative
3. If still blocked, STOP and ask the user
4. Never silently degrade quality to work around a problem
