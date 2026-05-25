# Contributing

Thanks for considering a contribution. `xspec` is solo-maintained and
experimental. The contribution model reflects that.

## Before opening anything

Read the [Status](./README.md#status) section. The project is pre-1.0; the
API may change. Big changes proposed without discussion are unlikely to land.

## Filing an issue

Use one of the [issue templates](./.github/ISSUE_TEMPLATE):
- **Bug** — something's broken
- **Feature request** — something should exist
- **Question** — anything else

Blank issues are disabled by design.

## Opening a PR

1. Open an issue first. We agree on the change before code is written.
2. One concern per PR. Small + reviewable beats large + monolithic.
3. Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`,
   `ci:`, `vendor:`, `sync:`, `test:`. Subject ≤ 70 chars.
4. No `Co-Authored-By` trailers.
5. `CHANGELOG.md` updates are automatic — release-please handles versioning
   from conventional commits.

## Coding conventions

- All Quint CLI calls in agent/command prose use `docker exec quint-runtime quint …` prefix. See [runtime-conventions.md](./plugins/xspec/references/runtime-conventions.md).
- Vendored content from upstream (`quint-co/quint-llm-kit`) lives in `plugins/xspec/{agents,commands,references,schemas,scripts}/`. See [docs/SYNCING.md](./docs/SYNCING.md) for the sync workflow.
- macOS BSD `sed` syntax (`sed -i ''`) — match the maintainer's machine.

## Running locally

See [README → First-run setup](./README.md#first-run-setup) + the
[smoke fixture](./tests/fixtures/bank.qnt).

## What's out of scope right now

- Windows support
- Backends other than Quint (TLA+, Alloy may come later — not yet)
- Choreo workflows (commands exist; not first-class supported in v1 demos)

If your change is in scope, opens cleanly, and the issue conversation
agrees on it: PR will get reviewed.
