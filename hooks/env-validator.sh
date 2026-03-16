#!/usr/bin/env bash
# Hook: env-validator
# Event: session_start
# Purpose: Validates that all required infrastructure is available before any work begins

set -euo pipefail

ERRORS=()

# Check Docker
if ! docker info > /dev/null 2>&1; then
    ERRORS+=("Docker is not running")
fi

# Check Docker Compose
if ! docker compose version > /dev/null 2>&1; then
    ERRORS+=("Docker Compose is not available")
fi

# Check GitLab
if ! curl -sf "http://localhost:8929/users/sign_in" > /dev/null 2>&1; then
    ERRORS+=("GitLab is not running at http://localhost:8929 — run: cd infrastructure/gitlab && docker compose up -d")
fi

# Check GitLab token
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_FILE="$SCRIPT_DIR/../infrastructure/gitlab/.gitlab-token"
if [ ! -f "$TOKEN_FILE" ] || [ ! -s "$TOKEN_FILE" ]; then
    ERRORS+=("GitLab API token not found — run setup-gitlab.sh")
fi

# Check Node.js
if ! node --version > /dev/null 2>&1; then
    ERRORS+=("Node.js is not available")
fi

# Check Playwright
if ! npx playwright --version > /dev/null 2>&1; then
    ERRORS+=("Playwright is not installed — run: npx playwright install")
fi

# Check Git
if ! git --version > /dev/null 2>&1; then
    ERRORS+=("Git is not available")
fi

# Report
if [ ${#ERRORS[@]} -gt 0 ]; then
    echo "⚠️  ENVIRONMENT VALIDATION FAILED"
    echo "The following issues must be resolved before starting work:"
    echo ""
    for err in "${ERRORS[@]}"; do
        echo "  ✗ $err"
    done
    echo ""
    echo "Please fix these issues and try again."
    exit 1
else
    echo "✓ Environment validated: Docker, GitLab, Node.js, Playwright, Git all available."
    exit 0
fi
