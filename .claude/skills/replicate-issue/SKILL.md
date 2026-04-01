---
name: replicate-issue
description: Reproduces a GitLab bug from an issue URL, collects evidence via Playwright, and posts a debugging report back to the issue
---

# Replicate Issue — Skill

You are a QA investigator. Given a GitLab issue URL, your job is to **reproduce the reported bug**, **collect evidence**, and **post a detailed debugging report** back to the issue — without fixing anything.

## Input
The user provides a GitLab issue URL (e.g., `http://gitlab.local:8929/agentforge/qptool-author/-/issues/18`).

## Steps

### 1. Read the Issue
- Fetch the issue title, description, and acceptance criteria via GitLab API
- Read all existing comments on the issue for additional context
- Identify what behavior is expected vs what's reported as broken

### 2. Design Reproduction Steps
Based on the issue description and comments, plan a Playwright test script that:
- Sets up the required preconditions (users, data, navigation)
- Exercises each acceptance criterion or reported bug
- Takes screenshots at every meaningful checkpoint
- Captures API responses for any backend interactions
- Logs findings as structured output

### 3. Run the Reproduction
Execute the Playwright script against the running local app:
- **App URL**: `http://localhost:3000` (frontend), `http://localhost:8000` (backend)
- **Auth**: Use `tests/.auth/session.json` for primary user, create additional sessions for multi-user scenarios
- **Screenshots**: Save to `test-results/issue{N}-*.png`
- If the bug involves multiple users, create separate browser contexts with separate sessions
- If the bug involves timing/polling, add appropriate waits and verify with API calls

### 4. Analyze Findings
For each acceptance criterion or reported behavior:
- Mark as ✓ (working), ✗ (broken), or ⚠️ (partially working)
- Include the actual vs expected behavior
- Identify the likely root cause (file + function + line if possible)
- Note any related bugs discovered during investigation

### 5. Upload Screenshots to GitLab
For each screenshot captured:
```bash
curl -s --header "PRIVATE-TOKEN: $TOKEN" \
  --form "file=@test-results/issueN-screenshot.png" \
  "http://gitlab.local:8929/api/v4/projects/$PROJECT_ID/uploads"
```
Collect the returned markdown image references.

### 6. Post Report to Issue
Post **two comments** to the GitLab issue:

**Comment 1 — Investigation Report:**
- Test setup (users, data, environment)
- Findings per acceptance criterion (with ✓/✗ status)
- Summary table of bugs found (number, description, severity, likely cause)
- Files to investigate (specific paths)

**Comment 2 — Screenshots:**
- Each screenshot with a descriptive heading explaining what it shows and what's wrong

Use this format for posting:
```bash
curl -s --request POST --header "PRIVATE-TOKEN: $TOKEN" \
  "http://gitlab.local:8929/api/v4/projects/$PROJECT_ID/issues/$ISSUE_IID/notes" \
  --data-urlencode "body=..."
```

## Output
- Screenshots saved locally in `test-results/`
- Two comments posted to the GitLab issue with full evidence
- No code changes made — investigation only

## Important Rules
- **Do NOT fix the bugs.** Only reproduce, document, and report.
- **Always take screenshots** — they are the primary evidence.
- **Test with real browser contexts** — no mocking, no API-only testing.
- **For multi-user bugs**, use separate browser contexts with different authenticated users.
- **Include API response details** when backend behavior is relevant.
- **Be specific about root causes** — name the file, function, and suspected logic error.
