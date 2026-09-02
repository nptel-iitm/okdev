# Isolated environment for exercising OKDev skills under the Codex CLI.
# Pinned so a harness result always refers to a known CLI version.
FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      git ripgrep ca-certificates curl python3 python3-pip python3-venv jq \
    && rm -rf /var/lib/apt/lists/*

# Test tooling the fixtures need, preinstalled so a run never spends model
# turns waiting on a package index.
RUN pip3 install --break-system-packages --no-cache-dir pytest==8.3.4 pytest-cov==6.0.0

# The Docker CLI and the Compose plugin, from Docker's own repository rather
# than Debian's. OKDev requires every project to come up with `docker compose
# up`, so a harness whose CLI cannot run that command can only ever test the
# path where Docker is missing. Debian's docker.io ships no compose plugin and
# a v20 client, against a v29 daemon on this host.
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/* \
    && docker --version && docker compose version

ARG CODEX_VERSION=0.145.0
RUN npm i -g "@openai/codex@${CODEX_VERSION}" && codex --version

# The harness runs the container as the host uid so artifacts stay writable.
WORKDIR /work
ENV CODEX_HOME=/codexhome
