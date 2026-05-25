---
command: /xspec:setup
description: Build (if needed) and start the Quint runtime container with the current workspace mounted
version: 1.0.0
---

# Setup the Quint Runtime

## Objective

Ensure the `quint-runtime` Docker container exists and is running, with the user's current working directory mounted at `/workspace`. Idempotent.

## Steps

1. **Check Docker availability**

```bash
docker info > /dev/null 2>&1
```

If this fails: tell the user "Docker daemon not reachable. Start Docker Desktop or your daemon, then re-run `/xspec:setup`." Stop.

2. **Check image presence**

```bash
docker image inspect quint-runtime:0.1.0 > /dev/null 2>&1
```

If absent, build it from the plugin's runtime directory:

```bash
PLUGIN_DIR="$(find ~/.claude -type d -name quint -path '*plugins/quint*' 2>/dev/null | head -1)"
docker build -t quint-runtime:0.1.0 -f "$PLUGIN_DIR/runtime/Dockerfile" "$PLUGIN_DIR/runtime/"
```

Inform the user this takes 5–10 minutes on first run.

3. **Check container presence**

```bash
docker ps -a --filter name=^quint-runtime$ --format '{{.Status}}'
```

- Empty output → no container exists → go to step 4.
- Output starts with `Up` → container running → skip to step 5.
- Output starts with `Exited` → container stopped → `docker start quint-runtime`, then step 5.

4. **Create + start container with workspace mount**

```bash
WORKSPACE="$(pwd)"
docker run -d \
  --name quint-runtime \
  -v "$WORKSPACE":/workspace \
  -w /workspace \
  quint-runtime:0.1.0 \
  tail -f /dev/null
```

5. **Verify Quint responds**

```bash
docker exec quint-runtime quint --version
```

Expected: version string.

6. **Report success**

Print to user:
```
✓ Quint runtime ready
  Container: quint-runtime
  Workspace: <pwd>:/workspace
  Quint:     <version from step 5>

MCP servers (quint-kb, quint-lsp) will be available on next Claude Code session restart,
or stay available if already wired.
```

## Failure handling

- Image build fails: surface the docker error, suggest checking network (npm install of @informalsystems/quint requires registry access).
- `docker run` fails with name conflict: container exists but in unexpected state. Run `docker rm -f quint-runtime` and retry.
- File ownership on Linux bind mounts: the container runs as in-image user `dev` (uid 1000). Files written under `/workspace` from the container appear as uid 1000 on the host. On macOS (Docker Desktop / OrbStack) host-user mapping is transparent. On native Linux with a non-1000 host uid, chown the workspace if you need to edit the container's writes from the host, or align your host user with uid 1000. Do NOT pass `--user "$(id -u):$(id -g)"` to `docker run` — the MCP server binaries live under `/home/dev` (mode 0700) and become unreachable for any user other than `dev`.
