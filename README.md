# Executable Specs

A Claude Code marketplace plugin for executable specifications — write specs,
verify invariants, debug counterexamples, and drive implementations from specs.
v1 backend: [Quint](https://quint.sh), running inside a Dockerized tool sandbox.

## Demo

[![xspec demo: verify a logistics workflow](https://asciinema.org/a/9xkm0LypeL6Admj3.svg)](https://asciinema.org/a/9xkm0LypeL6Admj3?autoplay=1)

> Click to play. Claude writes a Quint spec for a warehouse workflow, `xspec`
> finds a counterexample (damaged items can still ship), narrates it in plain
> language, and applies the fix.

## What you get

- **Skill** — `xspec` skill auto-triggers on spec/verify/debug/state-machine
  prompts and routes to the right phase.
- **Six agents** — analyzer, verifier, implementer, spec-implementer,
  mbt-validator, mbt-validator-standalone.
- **~20 slash commands** in four phases:
  - `/xspec:spec:*` — generate specs from docs/code
  - `/xspec:verify:*` — invariants, witnesses, counterexamples
  - `/xspec:code:*` — implementation from spec
  - `/xspec:refactor:*` — update spec as requirements change
- **Three lifecycle commands** — `/xspec:setup`, `/xspec:status`, `/xspec:teardown`.
- **MCP servers** — `quint-kb` (docs + semantic search), `quint-lsp` (types,
  hover, diagnostics), wired automatically via docker exec.
- **Runtime image** — `quint-runtime:0.1.0` bundling Quint, LSP, Apalache, the
  kb MCP server, and the LSP-MCP bridge.

## Prerequisites

- Claude Code CLI installed on host
- Docker daemon running (Docker Desktop on macOS/Windows or `dockerd` on Linux)
- ~2 GB free disk space for the runtime image

You do **not** need to install Quint, Apalache, or any language toolchains on
your host — they live in the container.

## Install

```bash
# In Claude Code, add this marketplace
/plugin marketplace add qdelettre/xspec
/plugin install xspec
```

(Or clone this repo and point Claude Code at it locally.)

## First-run setup

After install, in your project's working directory:

```
/xspec:setup
```

This builds the runtime image (~5–10 minutes first time) and starts the
container with your `cwd` mounted at `/workspace`. Subsequent setups are
instant.

## Usage

Just ask spec/verify questions. The skill triggers and routes:

> "Verify the consensus protocol always reaches agreement"
> → `/xspec:verify:start`

> "Write a spec for this Raft implementation"
> → `/xspec:spec:start`

Or invoke commands directly. See `plugins/xspec/commands/` for the full list.

## Architecture

Host Claude Code orchestrates; container executes. The container ships
[Quint](https://quint.sh) (the v1 backend). Future versions may add other
formal-spec backends (TLA+, Alloy, Dafny) as siblings.

## Acknowledgments

Unofficial. Not affiliated with [Informal Systems](https://informal.systems)
or the Quint maintainers. Built on top of
[quint-co/quint-llm-kit][upstream]'s agentic content (Apache-2.0).
See [NOTICE](./NOTICE) for full attribution.

[upstream]: https://github.com/quint-co/quint-llm-kit

## License

Apache-2.0. See [LICENSE](./LICENSE).
