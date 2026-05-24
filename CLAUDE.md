# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Claude Code marketplace shipping a single plugin (`xspec`) that orchestrates executable-specification workflows via a Dockerized runtime container. v1 backend is [Quint](https://quint.sh); the architecture leaves room for sibling backends later.

This is a **content + infrastructure** project — no application code. Deliverables are markdown (skill, agents, commands, references), JSON manifests, a Dockerfile, and a CI workflow. Most edits are sed-friendly mechanical rewrites or judgment-based content changes.

## Two-layer architecture

```
HOST: user's Claude Code
  └─ plugin: xspec (skill + agents + commands + references)
        │
        │ docker exec / MCP-over-docker-exec-stdio
        ▼
CONTAINER: quint-runtime (image: quint-runtime:0.1.0)
  ├─ quint CLI, quint-language-server, Apalache (JVM)
  ├─ kb MCP server (semantic doc search)
  └─ mcp-language-server bridge
```

Container has **no Claude Code inside** — it's a sealed tool sandbox. Host Claude orchestrates; container executes. Plugin's `mcpServers` in `plugins/xspec/.claude-plugin/plugin.json` declare both MCP servers with `command: docker`, `args: ["exec", "-i", "quint-runtime", ...]` so Claude Code spawns them as stdio transports through `docker exec`.

User workspace mounts at `/workspace`. Files written from host (e.g., `tests/fixtures/bank.qnt`) are immediately visible to the container's `quint` binary at the same relative path.

## Tool invocation convention

All Quint CLI calls go through:

```bash
docker exec quint-runtime quint <subcommand> [args]
```

Documented in `plugins/xspec/references/runtime-conventions.md`. **Never** alias this away — aliases don't propagate to non-interactive shells, subagents, or fresh Claude Code sessions. Every bash code block in agent/command/reference prose hard-codes the prefix.

## Slash command namespace

All commands use the `/xspec:*` namespace. Phase-grouped 3-level: `/xspec:setup`, `/xspec:spec:start`, `/xspec:verify:explain-trace`, `/xspec:code:start`, `/xspec:refactor:plan`. Plugin slug + repo name = `xspec`; marketplace name = `executable-specs` (semantic umbrella for any future backend plugins).

## Vendored upstream content

Most of `plugins/xspec/{agents,commands,references,schemas,scripts}/` is vendored from `quint-co/quint-llm-kit/agentic/` (Apache-2.0). Adapted with path rewrites, command namespace, docker-exec prefix, PLUGIN_DIR injection. **Always-authored** (never overwrite during sync):

- `plugins/xspec/skills/xspec/SKILL.md`
- `plugins/xspec/commands/{setup,teardown,status}.md`
- `plugins/xspec/references/runtime-conventions.md`
- `plugins/xspec/runtime/Dockerfile` (forked from upstream, heavily modified)

When upstream changes: follow `docs/SYNCING.md`. Baseline tracked in `.upstream-sha`. CI workflow `.github/workflows/sync-alert.yml` opens an `upstream-drift` issue weekly when divergence detected.

## Common commands

```bash
# Validate manifests
jq . .claude-plugin/marketplace.json
jq . plugins/xspec/.claude-plugin/plugin.json

# Build runtime image (~5-10 min first time; ~1-3 min thereafter with cache)
docker build -t quint-runtime:0.1.0 -f plugins/xspec/runtime/Dockerfile plugins/xspec/runtime/

# Start container with workspace mount
docker run -d --name quint-runtime -v "$(pwd)":/workspace -w /workspace quint-runtime:0.1.0 tail -f /dev/null

# Smoke fixture (always available, validates the full chain)
docker exec quint-runtime quint typecheck tests/fixtures/bank.qnt
docker exec quint-runtime quint run --invariant=safe --max-samples=200 --max-steps=20 tests/fixtures/bank.qnt

# Validate CI workflow locally
actionlint .github/workflows/sync-alert.yml

# Check drift against upstream (manual)
PINNED=$(cat .upstream-sha)
UPSTREAM=$(gh api repos/quint-co/quint-llm-kit/commits/main --jq .sha)
[ "$PINNED" = "$UPSTREAM" ] && echo IN_SYNC || gh api "repos/quint-co/quint-llm-kit/compare/${PINNED}...${UPSTREAM}" --jq '.files[].filename' | grep '^agentic/'

# Sanity sweep across plugin content
grep -rn '\.claude/' plugins/xspec/ && echo STALE_PATHS || echo PATHS_OK
grep -rn 'quint-marketplace' . --include='*.json' --include='*.yml' --include='*.md' --include='Dockerfile' | grep -v '.git' && echo STALE_NAME || echo NAME_OK
```

## CI gates (`.github/workflows/ci.yml`)

1. `jq` parses both manifests
2. Every `.md` under `plugins/xspec/{commands,agents}/` opens with `---` (frontmatter present)
3. `markdownlint-cli2` over plugin content + README + NOTICE (advisory, `continue-on-error: true`)
4. Smoke build of runtime image + `quint --version` + `which quint-language-server` + check kb MCP server file exists

Plus the separate sync-alert workflow on Mondays 06:00 UTC.

## "Tests"

No conventional test suite. The smoke fixture at `tests/fixtures/bank.qnt` is the canonical end-to-end check — typechecking it + running invariant `safe` against it exercises the full plugin → runtime → quint chain. After any change to the runtime or vendored content, re-run that fixture.

## Docs

User-facing canonical docs in `docs/SYNCING.md` and `README.md`.

## House rules in this repo

1. **No `Co-Authored-By` trailers** in commits. Project-wide.
2. **Commit messages prefix** with conventional types: `feat:`, `docs:`, `ci:`, `refactor:`, `fix:`, `chore:`, `vendor:`, `sync:`, `test:`.
3. **Bash `quint` calls in vendored content** must be wrapped with `docker exec quint-runtime ` if they're exec lines (not prose mentions, not `.qnt` source).
4. **`xspec` slug + repo + `executable-specs` marketplace + `quint-runtime` container/image** — these names are stable. Internal Quint references (in vendored content, in bash exec lines) stay as `quint` because they reference the actual binary.
