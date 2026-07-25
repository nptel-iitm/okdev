#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d /tmp/okdev-gitlab-config-test-XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT

run_fixture() {
    local fixture_dir="$1"
    local output_file="$2"

    mkdir -p "$fixture_dir/bin"
    cp "$REPO_DIR/infrastructure/gitlab/setup-gitlab.sh" "$fixture_dir/setup-gitlab.sh"
    cat > "$fixture_dir/bin/docker" <<EOF
#!/usr/bin/bash
touch "$fixture_dir/docker-was-called"
exit 1
EOF
    chmod +x "$fixture_dir/bin/docker"

    PATH="$fixture_dir/bin:/usr/bin:/bin" \
        /usr/bin/bash "$fixture_dir/setup-gitlab.sh" > "$output_file" 2>&1 || true
}

EVALUATION_FIXTURE="$TEST_ROOT/evaluation"
mkdir -p "$EVALUATION_FIXTURE"
printf 'GITLAB_ROOT_PASSWORD=$(touch %s)evaluated\n' \
    "$EVALUATION_FIXTURE/shell-evaluation-marker" > "$EVALUATION_FIXTURE/.env"
run_fixture "$EVALUATION_FIXTURE" "$EVALUATION_FIXTURE/output"
test ! -e "$EVALUATION_FIXTURE/shell-evaluation-marker"

PLACEHOLDER_FIXTURE="$TEST_ROOT/placeholder"
mkdir -p "$PLACEHOLDER_FIXTURE"
printf 'GITLAB_ROOT_PASSWORD=replace-with-a-strong-local-password\n' \
    > "$PLACEHOLDER_FIXTURE/.env"
run_fixture "$PLACEHOLDER_FIXTURE" "$PLACEHOLDER_FIXTURE/output"
test ! -e "$PLACEHOLDER_FIXTURE/docker-was-called"
grep -Fq "Replace the placeholder" "$PLACEHOLDER_FIXTURE/output"

echo "GitLab credential configuration smoke test passed."
