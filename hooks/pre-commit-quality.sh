#!/usr/bin/env bash
# Hook: pre-commit-quality
# Event: pre_commit (configured via git hooks or Claude Code hooks)
# Purpose: Runs linting and fast unit tests before allowing a commit

set -euo pipefail

echo "Running pre-commit quality checks..."

# Detect project type and run appropriate checks
if [ -f "package.json" ]; then
    # Node.js project
    if grep -q '"lint"' package.json 2>/dev/null; then
        echo "Running linter..."
        npm run lint || { echo "✗ Linting failed"; exit 1; }
    fi
    if grep -q '"test"' package.json 2>/dev/null; then
        echo "Running fast tests..."
        npm test -- --bail 2>/dev/null || npm test || { echo "✗ Tests failed"; exit 1; }
    fi
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
    # Python project
    if command -v ruff > /dev/null 2>&1; then
        echo "Running ruff..."
        ruff check . || { echo "✗ Linting failed"; exit 1; }
    elif command -v flake8 > /dev/null 2>&1; then
        echo "Running flake8..."
        flake8 . || { echo "✗ Linting failed"; exit 1; }
    fi
    if command -v pytest > /dev/null 2>&1; then
        echo "Running fast tests..."
        pytest -x -q --timeout=30 2>/dev/null || pytest -x -q || { echo "✗ Tests failed"; exit 1; }
    fi
elif [ -f "go.mod" ]; then
    # Go project
    echo "Running go vet..."
    go vet ./... || { echo "✗ Vet failed"; exit 1; }
    echo "Running tests..."
    go test -short ./... || { echo "✗ Tests failed"; exit 1; }
fi

echo "✓ Pre-commit checks passed"
