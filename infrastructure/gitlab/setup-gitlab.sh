#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITLAB_URL="http://localhost:8929"
GITLAB_ROOT_PASSWORD="AgentForge2024!"

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
    if curl -sf "$GITLAB_URL/-/readiness" > /dev/null 2>&1; then
        echo "GitLab is ready!"
        break
    fi
    sleep 10
    ELAPSED=$((ELAPSED + 10))
    echo "  Still waiting... (${ELAPSED}s)"
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "ERROR: GitLab did not become ready within ${MAX_WAIT}s"
    echo "Check logs: docker compose logs gitlab"
    exit 1
fi

# Step 4: Create a Personal Access Token for API access
echo "Creating API access token..."
TOKEN_RESPONSE=$(docker exec agentforge-gitlab gitlab-rails runner "
  user = User.find_by_username('root')
  token = user.personal_access_tokens.create!(
    name: 'agentforge-token',
    expires_at: 365.days.from_now,
    scopes: [:api, :read_user, :read_repository, :write_repository, :read_registry, :sudo]
  )
  puts token.token
" 2>/dev/null || echo "TOKEN_EXISTS")

if [ "$TOKEN_RESPONSE" = "TOKEN_EXISTS" ]; then
    echo "Token may already exist. Check .gitlab-token file or create manually."
else
    echo "$TOKEN_RESPONSE" > "$SCRIPT_DIR/.gitlab-token"
    echo "Token saved to $SCRIPT_DIR/.gitlab-token"
fi

# Step 5: Create the AgentForge group
echo "Setting up AgentForge group..."
TOKEN=$(cat "$SCRIPT_DIR/.gitlab-token" 2>/dev/null || echo "")
if [ -n "$TOKEN" ]; then
    curl -sf --header "PRIVATE-TOKEN: $TOKEN" \
        "$GITLAB_URL/api/v4/groups" \
        --data "name=AgentForge&path=agentforge&visibility=internal" \
        -o /dev/null 2>/dev/null || echo "Group may already exist"
    echo "AgentForge group created."
fi

echo ""
echo "=== GitLab Setup Complete ==="
echo "URL:      $GITLAB_URL"
echo "Username: root"
echo "Password: $GITLAB_ROOT_PASSWORD"
echo "Token:    $(cat "$SCRIPT_DIR/.gitlab-token" 2>/dev/null || echo 'check .gitlab-token')"
echo ""
echo "Next: Run the MCP server setup script."
