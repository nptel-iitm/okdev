# MCP Server Setup

`setup-mcp.sh` generates the root `.mcp.json` that `install-to-project.sh` copies into each target project.

## GitLab

- GitLab credentials come from `../gitlab/.gitlab-token`.
- `setup-mcp.sh` always includes the `gitlab` MCP server.

## Stitch

- Stitch is optional and is configured from `.env.local` in this folder.
- Start by copying `.env.local.example` to `.env.local`.
- Set `STITCH_API_KEY` to your real key.
- `STITCH_MCP_URL` defaults to `https://stitch.googleapis.com/mcp`.

## Commands

```bash
# One-time Stitch setup
./infrastructure/mcp-servers/configure-stitch.sh <YOUR_STITCH_API_KEY>

# Or manually edit infrastructure/mcp-servers/.env.local, then regenerate .mcp.json
./infrastructure/mcp-servers/setup-mcp.sh

# Install into a fresh project
./scripts/install-to-project.sh /path/to/project
```

`install-to-project.sh` refreshes `.mcp.json` from local secrets before copying it, and adds `.mcp.json` to the target project's `.gitignore`.
