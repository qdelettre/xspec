# Runtime Conventions

This plugin runs the Quint toolchain inside a Docker container named
`quint-runtime`. All `quint`, `quint-language-server`, and Apalache invocations
happen via `docker exec` from the host. This file documents how that boundary
works so agents and commands stay consistent.

## The container

- Name: `quint-runtime`
- Image: `quint-runtime:0.1.0`
- Workspace mount: host's current working directory → `/workspace` in container
- Lifecycle: created/started by `/xspec:setup`, stopped by `/xspec:teardown`,
  inspected by `/xspec:status`.

## Path equivalence

A file at host path `<cwd>/specs/foo.qnt` is visible inside the container at
`/workspace/specs/foo.qnt`. Relative paths work transparently because the
container's `WORKDIR` is `/workspace`.

```bash
# These two are equivalent in effect:
docker exec quint-runtime quint typecheck specs/foo.qnt           # relative
docker exec quint-runtime quint typecheck /workspace/specs/foo.qnt  # absolute
```

Prefer relative.

## Invoking Quint tools

Always prefix:

```bash
docker exec quint-runtime quint <subcommand> [args]
```

Subcommands you'll use: `typecheck`, `run`, `test`, `verify`, `parse`, `repl`.

Use `--backend=rust` for `quint run` invariant checks — it's faster.

```bash
docker exec quint-runtime quint run --backend=rust --invariant=safe specs/foo.qnt
```

## Why no shell alias

You may be tempted to suggest users alias `q='docker exec quint-runtime quint'`.
Don't. Aliases don't propagate to non-interactive shells, agent subprocesses, or
fresh Claude Code sessions. Hard-code `docker exec quint-runtime` in every bash
block agents emit.

## MCP servers

Two MCP servers run inside the container, transported over `docker exec` stdio:
- `quint-kb` — semantic search over Quint docs/examples
- `quint-lsp` — language server diagnostics, hover, definitions

Both declared in `plugins/xspec/.claude-plugin/plugin.json` and spawned by
Claude Code automatically once the container exists.

### MCP tool path arguments — always container-side

When calling MCP tools (`mcp__plugin_xspec_quint-lsp__*`, etc.) that take a
file path argument, the path is interpreted **inside the container**. Use the
`/workspace/...` form, NOT the host's `/tmp/...` or absolute host path.

```
# wrong: LSP can't see host paths
mcp__plugin_xspec_quint-lsp__definition(file: "/Users/me/proj/specs/foo.qnt")

# correct: workspace-relative or /workspace-absolute
mcp__plugin_xspec_quint-lsp__definition(file: "/workspace/specs/foo.qnt")
mcp__plugin_xspec_quint-lsp__definition(file: "specs/foo.qnt")
```

Mnemonic: bash code blocks use `docker exec` and CAN take either form (the
shell hands the path to the container's tool, which is in `/workspace`). MCP
calls bypass the shell, so the path goes straight to the in-container tool —
which only knows `/workspace`.

## Rust evaluator cache + parallel `quint run`

First time `quint run` executes inside a freshly built container, it downloads
the Rust evaluator binary (~50MB) into `/home/dev/.quint/rust-evaluator-*/`.
This download takes a few seconds and is cached for subsequent runs.

**Don't run multiple `quint run` invocations in parallel on a fresh container.**
The cache write races, one writes the binary while others read corruption,
and some runs fail with cryptic errors.

Pattern: run the first `quint run` sequentially. After the cache is populated
(verify with `ls /home/dev/.quint/rust-evaluator-*/quint_evaluator`), parallel
runs are fine.

The Dockerfile pre-warms this cache at build time so this only matters if you
rebuild the image yourself and skip the pre-warm step.

## .artifacts/ convention

Agents write planning artifacts (refactor-plan.json, requirement-analysis.json,
verification reports) to `.artifacts/` in the workspace. From the container's
perspective this is `/workspace/.artifacts/`. From the host it's `<cwd>/.artifacts/`.
Add `.artifacts/` to your project's `.gitignore` if you don't want them tracked.

## Failure recovery

If a `docker exec` command fails with "Error response from daemon: Container
quint-runtime is not running" or similar:

1. Run `/xspec:status` to inspect.
2. Run `/xspec:setup` to recreate.
3. Re-run the original command.
