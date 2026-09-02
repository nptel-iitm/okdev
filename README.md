# Over Kill Dev (OKDev)

Over Kill Dev (OKDev) is an autonomous software-development system for Claude Code and Codex. It coordinates specialized agents through a professional delivery cycle: requirements, architecture, issue planning, implementation, layered testing, review, and delivery.

OKDev is designed for complete project work rather than isolated code generation. The system uses local GitLab for source control and issue tracking, MCP for agent access to GitLab and optional design tooling, and files under `.okdev/` as the shared runtime contract between agents.

## Architecture

OKDev follows a hub-and-spoke model. The `/kickoff` skill in Claude Code or `$kickoff` skill in Codex acts as the master orchestrator. It delegates focused work to agents responsible for requirements, architecture, technical leadership, development, review, testing, design, and delivery.

Agents coordinate through two durable channels:

- GitLab issues, boards, branches, merge requests, and comments track project work.
- `.okdev/` documents and test artifacts pass structured outputs between phases.

The detailed operating policy and agent catalog live in [CLAUDE.md](CLAUDE.md).

There are two skill trees, one per harness, and they are not translations of
each other. `claude/skills/` targets Claude Code. `codex/skills/` targets Codex
and the GPT-5.6 models: Codex drops a skill between turns and compacts long
runs, so those skills keep their phase and loop counters in
`.okdev/run-state.json` and end in states an agent can reach without a human.
Running the Claude tree under Codex is what produced the never-ending workflows
in issue #15; see [tests/codex-harness/RESULTS.md](tests/codex-harness/RESULTS.md)
for the controlled experiment. `.claude/skills` is a symlink to `claude/skills`
so this repo still dogfoods itself in Claude Code.

## Capabilities

- Full greenfield delivery with `kickoff`
- Existing-project bug fixes with `bugfix`
- Requirements discovery from text, files, or audio
- Architecture design and human approval checkpoints
- GitLab issue, board, branch, and merge-request workflows
- Specialized implementation and code-review agents
- Unit, integration, end-to-end, UI screenshot, load, and manual testing
- UI design support with optional Google Stitch MCP integration
- Issue replication and replication-to-fix workflows
- Final delivery reporting

The skill families are:

- Orchestration: `kickoff`, `bugfix`, and multi-project variants
- Planning and leadership: `requirements-agent`, `architect-agent`, `tech-lead-agent`
- Delivery work: `dev-agent`, `code-review-agent`, `delivery-agent`
- Testing: planner, unit, integration, E2E, UI scoring, load, and manual-check agents
- Investigation: issue replication and replicate-then-kickoff workflows
- Design: `ui-designer-agent`
- Goal-driven QA: `manual-suite-driver`

## Prerequisites

- Linux or another environment capable of running the included Bash scripts
- Git
- Docker with Docker Compose
- Node.js and npm/npx
- Claude Code and/or Codex
- `curl` and `sudo` access to add `gitlab.local` to `/etc/hosts`
- GitHub CLI (`gh`) for contributing changes to this repository

The bootstrap is not fully containerized. `scripts/setup-all.sh` currently uses npm/npx on the host for Playwright and `infrastructure/mcp-servers/setup-mcp.sh` attempts a host-level global installation of `@zereight/mcp-gitlab`, falling back to npx when that global installation is unavailable.

## Quick start

1. Configure the local GitLab root password:

   ```bash
   cp infrastructure/gitlab/.env.example infrastructure/gitlab/.env
   # Edit infrastructure/gitlab/.env and set a strong GITLAB_ROOT_PASSWORD.
   ```

   The setup reads the literal text after `GITLAB_ROOT_PASSWORD=` without shell evaluation, so shell metacharacters remain part of the password. Do not wrap the value in shell quotes unless you intend those quote characters to be part of the password.

2. Bootstrap the ecosystem:

   ```bash
   ./scripts/setup-all.sh
   ```

3. Install OKDev into a target project:

   ```bash
   ./scripts/install-to-project.sh /absolute/path/to/project
   ```

4. Start your preferred runtime in the target project:

   ```bash
   cd /absolute/path/to/project
   claude
   # Invoke /kickoff
   ```

   Or:

   ```bash
   cd /absolute/path/to/project
   codex
   # Invoke $kickoff
   ```

Restart an already-running Codex session after installation so it discovers the installed skills.

## Running a workflow under Codex

Interactive Codex and `codex exec` behave differently in one way that matters:
interactive has no session limit and no retry, so **you** notice when a run
stops and invoke the skill again. `okdev-supervise` wraps `codex exec` and does
that for you, which is what you want for anything you are not sitting in front
of. Neither Codex mode has a timeout of its own; `--session-timeout` below is
the supervisor's, applied with `timeout(1)`.

### Check the environment first

The `environment` phase blocks on any of these, so it is quicker to check
yourself:

```bash
docker info >/dev/null && echo "docker ok"
curl -fsS -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  http://gitlab.local:8929/api/v4/version >/dev/null && echo "gitlab ok"
npx playwright --version
cat .mcp.json     # GitLab URL and the token env var
```

### Starting a new project

The brief is the highest-leverage thing you write. Say who uses it, the rules
that actually matter, what you do not need, and the scale — a page is plenty.

```bash
cat > BRIEF.md <<'EOF'
# ShiftSwap - nurses swap shifts without ringing the ward manager
...
EOF
```

Then a prompt naming your environment, because the run cannot guess it:

```bash
mkdir -p .okdev
cat > .okdev/prompt.txt <<'EOF'
$kickoff

Build the project described in BRIEF.md.

Environment:
- GitLab at http://gitlab.local:8929, token in the GITLAB_TOKEN environment
  variable (send it as the PRIVATE-TOKEN header). The project okdev/shiftswap
  exists and is empty. `git push origin` already has credentials.
- Docker is available. Bind published ports in the 18100-18199 range.
- Playwright and its browsers are installed and PLAYWRIGHT_BROWSERS_PATH is
  set. Run headless.
- Sub-agents are available. Delegate as your instructions describe.

Report what you built, what merged, what is open, and your readiness verdict.
EOF
```

Run it:

```bash
.okdev/bin/okdev-supervise \
  --skill kickoff --project "$PWD" \
  --prompt .okdev/prompt.txt \
  --session-timeout 10800 \
  --max-sessions 8
```

**Pass `--prompt` on a first run.** Without it the supervisor sends its resume
text, which tells the agent to continue work that does not exist yet. Later
sessions get the resume text automatically; that is the point of the flag.

### Fixing a bug

File the issue in GitLab, then point a workflow at it. Same shape for
`replicate-issue`, which investigates and never fixes, and
`replicate-and-kickoff`, which does both in one pass.

```bash
cat > .okdev/prompt.txt <<'EOF'
$bugfix

Fix issue #14 of okdev/shiftswap:
http://gitlab.local:8929/okdev/shiftswap/-/issues/14

[the same Environment block as above]

Take it through to a merged MR with a regression test, and report what merged.
EOF

.okdev/bin/okdev-supervise --skill bugfix --project "$PWD" --prompt .okdev/prompt.txt
```

A finished workflow does not block the next one: starting `bugfix` in a repo
where `kickoff` completed archives the old record under `.okdev/history/` and
begins a new run.

### Watching it

```bash
.okdev/bin/okdev-state next        # phase, what is finished, open loop budgets
tail -f .okdev/supervisor.log      # one line per session
```

What the supervisor's exit code means:

```
0  complete           the workflow finished
4  blocked            read .okdev/blocked.md - it needs a decision from you
5  budget spent       raise --budget-delta, or stop
6  no progress twice   another session will not fix this; look at it
7  session ceiling    raise --max-sessions
```

`4` and `6` mean stop and read. `0`, `5` and `7` are just limits being hit.

### Keeping it inside a quota

Metering is deployment-specific, so the supervisor takes a command rather than
assuming one:

```bash
export OKDEV_BUDGET_CMD='your-command-that-prints-percent-used'
.okdev/bin/okdev-supervise ... --budget-delta 5
```

Without `OKDEV_BUDGET_CMD` that check is skipped and `--max-sessions` is the
only ceiling. For scale: building a two-page brief into a tested, reviewed,
merged product cost about 4% of a weekly ChatGPT Pro window.

### Two traps worth knowing

**Container DNS.** If you run Codex inside Docker on a machine using Tailscale
MagicDNS, containers cannot reach the resolver and every run *stalls* rather
than failing — it reads like a hung agent. `tailscale set --accept-dns=false`,
or give the agent container `--network host`.

**`rm -f` is rejected** by Codex's command layer, and it fails the whole
compound command, not just that clause. When a command is rejected, change the
approach rather than retrying with different quoting.

## When a Codex run stops before it finishes

It will, and that is expected rather than a failure. A long workflow spans
several Codex sessions, and a session ends for reasons that have nothing to do
with your project: a wall-clock limit, an upstream *"Selected model is at
capacity"*, a dropped connection, or the model simply finishing its turn while
the workflow still has phases left. Building one small product took four
sessions, and each of those four things happened exactly once.

**What to do: run the same command again in the same directory.**

```bash
cd /absolute/path/to/project
codex
# Invoke $kickoff again
```

The workflow reads `.okdev/run-state.json`, sees which phases are finished and
how many review rounds each merge request has already had, and carries on from
there. It will not redo requirements, re-file issues, or restart a review loop
at zero. Check where it got to at any time with:

```bash
.okdev/bin/okdev-state next
```

To let it retry by itself, hand it to the supervisor, which keeps starting
sessions until the workflow reaches its own terminal state:

```bash
.okdev/bin/okdev-supervise --skill kickoff --project "$PWD"
```

It stops on its own when the workflow is **complete**, when the workflow
**blocks** on something only you can decide (read `.okdev/blocked.md`), after
two sessions with no forward progress, or at limits you set with
`--max-sessions` and `--budget-delta`. It will not loop forever and it will not
keep paying for a workflow that has stopped moving.

Two states mean *stop and read*, not *run it again*:

- `.okdev/blocked.md` exists — the run needs a decision or an unreachable
  service. The file says what finished, what it was waiting on, and how to
  resume once you have fixed it.
- The supervisor reports no forward progress. Something is wrong that another
  session will not fix.

## What installation changes

`scripts/install-to-project.sh`:

- Asks which harness you are installing for, or takes `--harness claude|codex|both`.
- For Claude Code: copies `claude/skills/` to `<target>/.claude/skills/`, plus
  `CLAUDE.md` and `.claude/settings.json`.
- For Codex: copies `codex/skills/` to `${CODEX_HOME:-~/.codex}/skills/`, writes
  `AGENTS.md` into the target, and installs the run-state helper at
  `<target>/.okdev/bin/okdev-state`. That helper is what makes a long Codex run
  survive a compaction, so a Codex install without it will loop.
- Backs up conflicting Codex skills under `${CODEX_HOME:-~/.codex}/okdev-backups/<timestamp>/` before replacing them.
- Copies `.claude/settings.json` into the target.
- Copies or appends the repository's `CLAUDE.md` policy.
- Refreshes and copies `.mcp.json` when local credentials are available, then adds it to the target `.gitignore`.
- Creates `.okdev/test-results/screenshots/{e2e,ui,manual}/` as the runtime artifact tree.

The installer preserves its target-directory safety check and will stop if the requested target does not exist.

## Runtime artifacts

Agents write their shared outputs under the target project's `.okdev/` directory. Depending on the workflow, these include:

- `requirements.md`, `architecture.md`, `ui-design.md`, and `test-plan.md`
- orchestration and technical-lead logs
- unit, integration, E2E, UI, load, and manual test reports
- screenshots under `.okdev/test-results/screenshots/`
- `test-report.md` and `delivery-report.md`

These paths are producer/consumer contracts shared by the agent skills. If you customize one, update every agent that reads or writes it.

## Local GitLab

Docker Compose runs GitLab CE at `http://gitlab.local:8929` with SSH on port `2224`.

- Compose service: `gitlab`
- Container: `okdev-gitlab`
- GitLab group display name: `Over Kill Dev`
- GitLab group path: `okdev`
- Root username: `root`
- Root password source: ignored `infrastructure/gitlab/.env`
- Generated API token: ignored `infrastructure/gitlab/.gitlab-token`
- Persistent volumes: `gitlab_config`, `gitlab_logs`, and `gitlab_data`

`GITLAB_ROOT_PASSWORD` configures only the initial root password for a fresh GitLab data volume. Changing the value does not reset the password for an existing installation. For an existing volume, reset the root password explicitly through GitLab, or intentionally recreate the data only if losing the existing local GitLab state is acceptable.

To inspect the service without changing it:

```bash
cd infrastructure/gitlab
export GITLAB_ROOT_PASSWORD='temporary-validation-value'
docker compose config
docker compose ps
```

## MCP servers and Stitch

`infrastructure/mcp-servers/setup-mcp.sh` reads the local GitLab API token and generates the ignored root `.mcp.json`. The project installer copies that file into the target project so Claude Code or Codex can access local GitLab.

Google Stitch is optional. Copy `infrastructure/mcp-servers/.env.local.example` to `.env.local` and configure the key, or run:

```bash
./infrastructure/mcp-servers/configure-stitch.sh <YOUR_STITCH_API_KEY>
```

See [infrastructure/mcp-servers/README.md](infrastructure/mcp-servers/README.md) for MCP-specific setup and regeneration details.

## Repository layout

```text
.
├── claude/skills/                  Skill tree for Claude Code
├── codex/skills/                   Skill tree for Codex / GPT-5.6
├── codex/lib/okdev-state           Durable run state for Codex workflows
├── codex/AGENTS.md                 Shared operating rules for Codex
├── .claude/skills -> claude/skills Symlink, so this repo dogfoods itself
├── hooks/                          Environment and pre-commit checks
├── infrastructure/gitlab/          Local GitLab Compose and bootstrap
├── infrastructure/mcp-servers/     MCP and optional Stitch configuration
├── scripts/                        Ecosystem and target-project installers
├── tests/                          Repository smoke tests
├── CLAUDE.md                       Shared system policy
└── README.md                       Project setup and overview
```

## Testing changes

Before opening a pull request:

```bash
# Syntax-check every shell script.
find . -type f -name '*.sh' -not -path './.git/*' -print0 | xargs -0 -n1 bash -n

# Exercise the target installer with isolated HOME and CODEX_HOME directories.
bash tests/install-to-project-smoke.sh

# Durable run state and the supervisor: starting a second workflow, loop
# budgets, and the terminal states that stop a supervisor.
bash tests/okdev-state-smoke.sh

# Structural checks on the Codex skill tree. Both are free - no model calls.
python3 tests/codex-harness/lint-skills.py codex/skills
bash tests/codex-harness/check-catalog.sh codex/skills

# Validate the Compose model without starting GitLab.
GITLAB_ROOT_PASSWORD='temporary-validation-value' \
  docker compose -f infrastructure/gitlab/docker-compose.yml config

git diff --check
```

Changes to agent contracts should also be checked for consistent `.okdev/` producer and consumer paths.

## Troubleshooting

- `GITLAB_ROOT_PASSWORD is not configured`: copy `infrastructure/gitlab/.env.example` to `.env` and set the value.
- GitLab is unavailable: run `docker compose up -d` in `infrastructure/gitlab/`, then inspect `docker compose ps` and `docker compose logs gitlab`.
- `gitlab.local` does not resolve: add `127.0.0.1 gitlab.local` to `/etc/hosts`; the setup script attempts this with `sudo`.
- No GitLab MCP token: rerun `infrastructure/gitlab/setup-gitlab.sh`, then `infrastructure/mcp-servers/setup-mcp.sh`.
- No `.mcp.json` in a target: finish GitLab/MCP setup and rerun the target installer.
- Codex cannot find a skill: restart Codex after installation and confirm `${CODEX_HOME:-~/.codex}/skills/` contains the skill.
- A Codex run repeats a phase it already finished: check that `<target>/.okdev/bin/okdev-state` exists and `okdev-state next` reports the run. Without it there is nothing for the workflow to resume from.
- Existing GitLab password did not change: initial-password configuration does not modify an existing data volume; use GitLab's password-reset procedure.

## Security-sensitive local files

The following files are intentionally ignored and must not be committed:

- `infrastructure/gitlab/.env`
- `infrastructure/gitlab/.gitlab-token`
- `infrastructure/mcp-servers/.env.local`
- `.mcp.json` and target-project copies of it

Use the committed `.env.example` files as templates. Do not put real passwords, API keys, or tokens in examples, documentation, commits, logs, or pull-request descriptions.

## Contributing

Create a feature branch from `main`, keep commits focused, run the verification commands above, and open a GitHub pull request. Do not commit directly to `main`. Describe breaking changes and local credential/configuration changes prominently in the pull request.

## License

This project is licensed under the [MIT License](LICENSE).
