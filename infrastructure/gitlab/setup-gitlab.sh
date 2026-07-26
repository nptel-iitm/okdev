#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITLAB_URL="http://localhost:8929"
GITLAB_CONTAINER_NAME="okdev-gitlab"
TOKEN_FILE="$SCRIPT_DIR/.gitlab-token"
ENV_FILE="$SCRIPT_DIR/.env"
PLACEHOLDER_PASSWORD="replace-with-a-strong-local-password"

if [ -z "${GITLAB_ROOT_PASSWORD+x}" ] && [ -f "$ENV_FILE" ]; then
    PASSWORD_ENTRY_COUNT=0
    while IFS= read -r ENV_LINE || [ -n "$ENV_LINE" ]; do
        ENV_LINE="${ENV_LINE%$'\r'}"
        case "$ENV_LINE" in
            GITLAB_ROOT_PASSWORD=*)
                PASSWORD_ENTRY_COUNT=$((PASSWORD_ENTRY_COUNT + 1))
                GITLAB_ROOT_PASSWORD="${ENV_LINE#GITLAB_ROOT_PASSWORD=}"
                ;;
        esac
    done < "$ENV_FILE"

    if [ "$PASSWORD_ENTRY_COUNT" -gt 1 ]; then
        echo "ERROR: $ENV_FILE contains multiple GITLAB_ROOT_PASSWORD entries."
        exit 1
    fi
fi

if [ -z "${GITLAB_ROOT_PASSWORD:-}" ]; then
    echo "ERROR: GITLAB_ROOT_PASSWORD is not configured."
    echo "Copy $SCRIPT_DIR/.env.example to $ENV_FILE and set a strong local password."
    exit 1
fi

if [ "$GITLAB_ROOT_PASSWORD" = "$PLACEHOLDER_PASSWORD" ]; then
    echo "ERROR: Replace the placeholder GITLAB_ROOT_PASSWORD in $ENV_FILE."
    exit 1
fi

export GITLAB_ROOT_PASSWORD

echo "=== Over Kill Dev (OKDev) GitLab Setup ==="

# Step 1: Add gitlab.local to /etc/hosts if not present
if ! grep -q "gitlab.local" /etc/hosts 2>/dev/null; then
    echo "Adding gitlab.local to /etc/hosts..."
    echo "127.0.0.1 gitlab.local" | sudo tee -a /etc/hosts
fi

# Step 2: Start GitLab
echo "Starting GitLab (this takes 3-5 minutes on first run)..."
cd "$SCRIPT_DIR"
docker compose up -d

# Step 3: Wait for GitLab to be healthy
echo "Waiting for GitLab to become ready..."
MAX_WAIT=600
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    HEALTH_STATUS="$(docker inspect --format '{{if .State.Running}}{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}{{else}}stopped{{end}}' "$GITLAB_CONTAINER_NAME" 2>/dev/null || echo "missing")"
    if [ "$HEALTH_STATUS" = "healthy" ]; then
        echo "GitLab is ready (container health check passed)."
        break
    fi

    if docker exec "$GITLAB_CONTAINER_NAME" curl -sf "http://localhost:8929/-/readiness" > /dev/null 2>&1; then
        echo "GitLab is ready (internal readiness endpoint passed)."
        break
    fi

    sleep 10
    ELAPSED=$((ELAPSED + 10))
    echo "  Still waiting... (${ELAPSED}s, status: ${HEALTH_STATUS})"
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "ERROR: GitLab did not become ready within ${MAX_WAIT}s"
    echo "Check logs: docker compose logs gitlab"
    exit 1
fi

# Step 4: Create a Personal Access Token for API access
echo "Creating API access token..."
EXISTING_TOKEN="$(cat "$TOKEN_FILE" 2>/dev/null || true)"
if [ -n "$EXISTING_TOKEN" ] && curl -sf --header "PRIVATE-TOKEN: $EXISTING_TOKEN" "$GITLAB_URL/api/v4/user" > /dev/null 2>&1; then
    TOKEN_RESPONSE="$EXISTING_TOKEN"
    echo "Reusing existing API token from $TOKEN_FILE"
else
    TOKEN_RESPONSE="$(docker exec "$GITLAB_CONTAINER_NAME" gitlab-rails runner "
      user = User.find_by_username('root')
      token = user.personal_access_tokens.create!(
        name: 'okdev-token-api',
        expires_at: 365.days.from_now,
        scopes: [:api]
      )
      puts token.token
    " 2>/dev/null || echo "TOKEN_CREATE_FAILED")"
fi

if [ -z "$TOKEN_RESPONSE" ] || [ "$TOKEN_RESPONSE" = "TOKEN_CREATE_FAILED" ]; then
    echo "Token may already exist. Check .gitlab-token file or create manually."
else
    echo "$TOKEN_RESPONSE" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    echo "Token saved to $TOKEN_FILE"
fi

# Step 5: Create the Over Kill Dev group
echo "Setting up Over Kill Dev group..."
TOKEN="$(cat "$TOKEN_FILE" 2>/dev/null || echo "")"
if [ -n "$TOKEN" ]; then
    if curl -sf --header "PRIVATE-TOKEN: $TOKEN" \
        "$GITLAB_URL/api/v4/groups/okdev" \
        > /dev/null 2>&1; then
        echo "Over Kill Dev group already exists."
    else
        curl -sf --header "PRIVATE-TOKEN: $TOKEN" \
            "$GITLAB_URL/api/v4/groups" \
            --data-urlencode "name=Over Kill Dev" \
            --data "path=okdev&visibility=internal" \
            -o /dev/null 2>/dev/null
        echo "Over Kill Dev group created."
    fi
fi

echo ""
echo "=== GitLab Setup Complete ==="
echo "URL:      $GITLAB_URL"
echo "Username: root"
echo "Password: configured locally in $ENV_FILE (not displayed)"
echo "Token:    stored in $TOKEN_FILE (not displayed)"
echo "Note: the configured initial password only applies to a fresh GitLab data volume."
echo ""
echo "Next: Run the MCP server setup script."
