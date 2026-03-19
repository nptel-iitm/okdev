# Codex Compatibility Plan For AgentForge

## Current State

- Branch: `codex`
- Repo currently targets Claude Code installation and invocation.
- Installer behavior today:
  - Copies skills into `.claude/skills`
  - Copies `.claude/settings.json`
  - Copies or appends `CLAUDE.md`
  - Prints Claude-specific startup instructions: `claude` then `/kickoff`
- Skill payload already exists and is structured as reusable `SKILL.md` folders under `.claude/skills/<skill-name>/`.

## What Has Already Been Confirmed

### 1. Codex cannot use the current setup out of the box

Reason:
- The repo currently installs only Claude-specific assets into project-local `.claude/...` paths.
- Codex skill documentation in this environment points to custom skills being installed into `~/.codex/skills` (`$CODEX_HOME/skills`), not `.claude/skills`.
- Several skill instructions reference Claude-specific orchestration concepts such as the Claude `Agent` tool and Claude vision wording.

### 2. The reusable part is the skill content itself

Reason:
- The skills are already written as `SKILL.md` files with YAML front matter.
- That format is close to what Codex expects for custom skills.
- The main incompatibilities appear to be:
  - installation target
  - invocation guidance
  - a few Claude-specific tool references inside the skill bodies

## Goal

Make the least amount of change needed so Codex can use the same multi-agent system, while preserving:

- the skill name `kickoff`
- the overall AgentForge workflow
- the current Claude support
- the existing repo structure as much as possible

## Constraints

- Prefer additive changes over broad refactors.
- Do not break the existing Claude installation path.
- Keep the Codex version aligned with the same agent names and conventions.
- Minimize duplication unless duplication is the simplest low-risk compatibility layer.

## Proposed Implementation Strategy

### Phase 1: Add Codex-native skill installation support

Update `scripts/install-to-project.sh` so it supports Codex in addition to Claude.

Expected changes:
- Continue installing the Claude assets exactly as today.
- Add a Codex install path that copies the same skill folders into `~/.codex/skills/` or `$CODEX_HOME/skills/` when available.
- Ensure the install script is idempotent enough for repeated setup in new projects.
- Update the final output text so it clearly tells the user:
  - how Claude starts the system
  - how Codex starts the system

Decision point during implementation:
- Prefer installing to `${CODEX_HOME:-$HOME/.codex}/skills` because that matches Codex’s documented custom skill location.
- Avoid inventing a project-local `.codex/skills` convention unless there is hard evidence that Codex loads project-local skills automatically.

### Phase 2: Add minimal Codex skill metadata

For the Codex-installed skills, add only the metadata that materially improves Codex usability.

Expected changes:
- Add `agents/openai.yaml` for at least the `kickoff` skill.
- Consider whether all skills need `agents/openai.yaml` or whether only `kickoff` needs it.

Preferred minimum:
- Start with `kickoff` only unless testing shows Codex benefits materially from metadata on every skill.

Metadata goals:
- Human-friendly display name
- short description
- default prompt that explicitly references `$kickoff`

Note:
- Codex explicit skill invocation syntax is documented as `$skill-name`.
- The user wants to preserve `/kickoff` naming/conventions, so the docs should preserve the `kickoff` name and mention `/kickoff` as the Claude entrypoint, while explaining Codex’s invocation clearly rather than pretending `/kickoff` is native if it is not.

### Phase 3: Patch the skill instructions that are Claude-specific

Update only the instructions that would cause the orchestrator to behave incorrectly in Codex.

Likely files to update:
- `.claude/skills/kickoff/SKILL.md`
- `.claude/skills/tech-lead-agent/SKILL.md`
- `.claude/skills/test-planner-agent/SKILL.md`
- `.claude/skills/ui-screenshot-scorer/SKILL.md`
- possibly `CLAUDE.md` if a shared top-level doc should mention Codex compatibility

Expected content changes:
- Replace references to the Claude `Agent` tool with Codex-compatible sub-agent language.
- Refer to Codex sub-agent behavior in generic terms where possible so the same text still works conceptually for Claude.
- Replace “Claude vision” wording with model-agnostic image analysis wording.
- Remove or adapt front matter fields that are Claude-only if they would be problematic for Codex.

Preferred wording style:
- “Spawn a sub-agent” instead of “use Agent tool with subagent_type...”
- “Use the model’s image analysis capabilities” instead of “Claude’s vision capabilities”

### Phase 4: Decide how to avoid maintaining two divergent skill trees

This is the main design choice for keeping the change set small.

Options:

#### Option A: Keep `.claude/skills` as the source of truth and install the same folders into Codex

Pros:
- Smallest change
- Lowest maintenance overhead
- Preserves current repo shape

Cons:
- The folder name remains Claude-branded even though the content becomes cross-compatible

#### Option B: Introduce a neutral shared skill source (for example `skills/`) and install into both runtimes from there

Pros:
- Cleaner long-term structure

Cons:
- Larger diff
- More risk
- Not the “least amount of changes”

Recommended:
- Use Option A for this branch.

### Phase 5: Update setup and documentation text

Files likely to update:
- `scripts/setup-all.sh`
- `scripts/install-to-project.sh`
- `CLAUDE.md` only if needed for shared instructions

Expected changes:
- Clarify that AgentForge supports both Claude Code and Codex.
- Keep Claude startup instructions intact.
- Add Codex startup instructions.
- Document the exact Codex invocation for kickoff.

## Detailed Task Breakdown

### Task 1: Patch installer for dual-runtime support

Checklist:
- Add detection or default resolution for `CODEX_HOME`
- Create target directory under `~/.codex/skills`
- Copy skill folders into Codex skill dir
- Avoid clobbering unexpectedly without explicit intent
- Print post-install instructions for both runtimes

Acceptance criteria:
- Running the installer leaves Claude support unchanged.
- Running the installer also places AgentForge skills where Codex can discover them.

### Task 2: Add Codex metadata for kickoff

Checklist:
- Create `agents/openai.yaml` under the `kickoff` skill
- Set display name and short description
- Add `default_prompt` mentioning `$kickoff`

Acceptance criteria:
- Codex has a user-facing metadata layer for the main entrypoint skill.

### Task 3: Make the kickoff skill orchestration wording runtime-compatible

Checklist:
- Replace Claude Agent-tool wording
- Preserve the ordered SDLC phases
- Keep the name `kickoff`
- Clarify Codex/Claude invocation expectations in the docs

Acceptance criteria:
- A Codex run using the kickoff skill would not be instructed to call a nonexistent Claude-specific tool.

### Task 4: Make downstream agent docs runtime-compatible

Checklist:
- Update `tech-lead-agent` to use generic sub-agent wording
- Update `test-planner-agent` to use generic sub-agent wording
- Update `ui-screenshot-scorer` to remove Claude-specific vision wording

Acceptance criteria:
- No critical runtime instructions remain that depend on Claude-only tool names.

### Task 5: Sanity-check installation result

Checklist:
- Run the installer against a temp target directory
- Verify Claude assets are copied as before
- Verify Codex skill directories are created under the expected Codex home
- Inspect resulting files for expected structure

Acceptance criteria:
- The installed layout matches both runtime expectations.

### Task 6: Final verification and handoff notes

Checklist:
- Review `git diff`
- Summarize exact changes
- Note any remaining limitation, especially around `/kickoff` vs `$kickoff`

Acceptance criteria:
- The repo is left on `codex` branch with a clear explanation of how to use the updated system.

## Open Questions To Resolve During Execution

### 1. Should Codex startup be documented as `/kickoff` or `$kickoff`?

Current best understanding:
- Codex custom skills are explicitly documented with `$skill-name`.
- Claude uses `/kickoff`.

Recommended handling:
- Preserve the skill name `kickoff`.
- Preserve `/kickoff` as the Claude convention.
- Document Codex invocation honestly as `$kickoff` unless the runtime proves `/kickoff` works.

### 2. Should every skill get `agents/openai.yaml`?

Recommended handling:
- Start with `kickoff` only.
- Expand only if there is a clear benefit.

### 3. Should top-level docs be renamed away from `CLAUDE.md`?

Recommended handling:
- No, not in this branch.
- Keep existing Claude compatibility and add Codex-specific guidance only where needed.

## Risks

- If the installer writes directly into `~/.codex/skills`, repeated installs could overwrite an existing local skill set with the same names.
- If Codex requires a restart to pick up newly installed skills, the docs must state that clearly.
- If some YAML front matter fields are ignored or unsupported by Codex, the skill still likely works, but metadata may need refinement.
- If the repo later diverges between Claude and Codex behavior, shared skill text could become harder to maintain.

## Recommended Execution Order After Model Switch

1. Update `scripts/install-to-project.sh`
2. Add Codex metadata for `kickoff`
3. Patch Claude-specific orchestration wording in shared skills
4. Update setup/install messaging
5. Run a temp install and inspect results
6. Review diff and summarize usage

## Definition Of Done

This branch is done when:

- Codex can discover and use the AgentForge skills after installation.
- The system still works for Claude users.
- The `kickoff` name is preserved.
- The remaining differences in invocation syntax are documented accurately.
- The diff stays narrow and focused on compatibility, not a repo redesign.
