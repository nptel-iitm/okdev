#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITLAB_URL="http://localhost:8929"
GITLAB_ROOT_PASSWORD="AgentForge2024!"
GITLAB_CONTAINER_NAME="agentforge-gitlab"
TOKEN_FILE="$SCRIPT_DIR/.gitlab-token"

echo "=== AgentForge GitLab Setup ==="

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
        name: 'agentforge-token-api',
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
    echo "Token saved to $TOKEN_FILE"
fi

# Step 5: Create the AgentForge group
echo "Setting up AgentForge group..."
TOKEN="$(cat "$TOKEN_FILE" 2>/dev/null || echo "")"
if [ -n "$TOKEN" ]; then
    if curl -sf --header "PRIVATE-TOKEN: $TOKEN" \
        "$GITLAB_URL/api/v4/groups/agentforge" \
        > /dev/null 2>&1; then
        echo "AgentForge group already exists."
    else
        curl -sf --header "PRIVATE-TOKEN: $TOKEN" \
            "$GITLAB_URL/api/v4/groups" \
            --data "name=AgentForge&path=agentforge&visibility=internal" \
            -o /dev/null 2>/dev/null
        echo "AgentForge group created."
    fi
fi

echo ""
echo "=== GitLab Setup Complete ==="
echo "URL:      $GITLAB_URL"
echo "Username: root"
echo "Password: $GITLAB_ROOT_PASSWORD"
echo "Token:    $(cat "$TOKEN_FILE" 2>/dev/null || echo 'check .gitlab-token')"
echo ""
echo "Next: Run the MCP server setup script."
