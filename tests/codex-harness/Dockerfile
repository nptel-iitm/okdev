# Isolated environment for exercising OKDev skills under the Codex CLI.
# Pinned so a harness result always refers to a known CLI version.
FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      git ripgrep ca-certificates curl python3 python3-pip python3-venv jq \
    && rm -rf /var/lib/apt/lists/*

# Test tooling the fixtures need, preinstalled so a run never spends model
# turns waiting on a package index.
RUN pip3 install --break-system-packages --no-cache-dir pytest==8.3.4 pytest-cov==6.0.0

ARG CODEX_VERSION=0.145.0
RUN npm i -g "@openai/codex@${CODEX_VERSION}" && codex --version

# The harness runs the container as the host uid so artifacts stay writable.
WORKDIR /work
ENV CODEX_HOME=/codexhome
