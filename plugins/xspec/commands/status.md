---
command: /xspec:status
description: Report Quint runtime container state, image presence, and tool versions
version: 1.0.0
---

# Quint Runtime Status

## Objective

One-shot diagnostic: tell the user whether the runtime is healthy.

## Steps

1. **Image presence**

```bash
docker image inspect quint-runtime:0.1.0 --format '{{.Id}}' 2>/dev/null
```

Report: present (with digest) / absent.

2. **Container state**

```bash
docker ps -a --filter name=^quint-runtime$ --format '{{.Status}}\t{{.Mounts}}'
```

Report: running / stopped / not created. If running, show mounts.

3. **Tool versions (only if running)**

```bash
docker exec quint-runtime quint --version
docker exec quint-runtime which quint-language-server
docker exec quint-runtime ls /home/dev/mcp-servers/kb/dist/server.js
```

Report each on its own line.

4. **MCP availability hint**

Run a quick MCP query if available (e.g., `mcp__quint-kb__search`). If it returns, MCP is wired. If not, suggest restarting Claude Code or running `/xspec:setup`.

## Output format

```
Image:     ✓ quint-runtime:0.1.0 (sha256:...)
Container: ✓ Up 2 hours, /Users/qd/myproject → /workspace
Quint:     ✓ 0.25.x
LSP:       ✓ /usr/bin/quint-language-server
KB MCP:    ✓ /home/dev/mcp-servers/kb/dist/server.js
MCP wired: ✓ (or "✗ restart Claude Code")
```
