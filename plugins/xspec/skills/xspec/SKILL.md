---
name: xspec
description: |
  Use when the user asks for executable specifications, model checking, protocol
  verification, invariant proofs, state-machine modeling, race-condition
  debugging, or any task expressible as "verify property P holds in system S".

  Triggers (auto):
    - "spec this protocol", "model X formally", "executable spec for Y"
    - "verify invariant", "prove that Z", "is P always true?"
    - "can the system reach state W?", "reachability of ..."
    - "race condition in ...", "why does this concurrent code ..."
    - "state machine for ...", "transition system"
    - "counterexample", "explain this .itf.json", "trace failure"
    - "implement from this spec", "drive code from model"
    - "refactor the model", "update spec to match new requirements"

  Slash commands available: /xspec:setup, /xspec:status, /xspec:teardown,
  /xspec:spec:*, /xspec:verify:*, /xspec:code:*, /xspec:refactor:*

  Orchestrates the Quint CLI, quint-kb MCP, quint-lsp MCP, and 6 phase agents
  via a Dockerized runtime (no Claude Code inside container — pure tool surface).
---

# xspec orchestration skill

## Preflight (on every activation)

1. Check Docker daemon: `docker info > /dev/null 2>&1`. If fails → stop, tell
   user to start Docker.
2. Check runtime: `docker ps --filter name=^quint-runtime$ -q`. If empty →
   tell user to run `/xspec:setup` first. Stop.
3. Sanity: `docker exec quint-runtime quint --version`. If fails → suggest
   `/xspec:status` then `/xspec:setup`. Stop.

Once preflight passes, route to the appropriate command/agent for the user's
question category.

## Routing by question category

| User intent | Route to |
|---|---|
| "I don't know where to start" | `/xspec:spec:next` |
| "Write a spec from these docs" | `/xspec:spec:start` |
| "Distributed protocol with message-passing" | `/xspec:spec:setup-choreo` then `/xspec:spec:start` |
| "Check my model is right" | `/xspec:verify:start` |
| "Can state X be reached?" | `/xspec:verify:generate-witness` |
| "Why does this counterexample happen?" | `/xspec:verify:explain-trace` |
| "Why can't scenario S be reached?" | `/xspec:verify:debug-witness` |
| "Are all message types reachable?" | `/xspec:verify:check-types` |
| "Are all listeners hit?" (Choreo) | `/xspec:verify:check-listeners` |
| "Implement from my spec" | `/xspec:code:start` then `/xspec:code:orchestrate-migration` |
| "Update spec for new requirements" | `/xspec:refactor:start` |

## Tool invocation convention

All Quint CLI calls MUST use `docker exec quint-runtime quint ...`. See
@references/runtime-conventions.md for details.

## When to use sub-agents

The agents (analyzer, verifier, implementer, spec-implementer, mbt-validator,
mbt-validator-standalone) load in isolated context. Dispatch them via the
Task tool when:

- A user request needs heavy iteration over a single concern (e.g. verifying
  many invariants → use `verifier` agent so main context stays clean).
- The work involves planning artifacts in `.artifacts/` (e.g. refactor
  planning → `analyzer`).

For one-shot questions ("what does this error mean?") stay in main context.

## Degradation

- MCP servers unavailable: works using `quint --help`, `quint typecheck` output,
  and reasoning over `.itf.json` files directly. Inform user that semantic
  doc search is degraded; suggest restarting Claude Code session to pick up
  MCP servers after `/xspec:setup`.
- Container down but image present: skill instructs `/xspec:setup` to start.
- Image absent: `/xspec:setup` will build it (warn ~5-10 min).

## What this skill does NOT do

- Teach Quint syntax in prose. Use `mcp__quint-kb__*` or quint-lang.org/docs/.
- Re-implement Apalache or the Quint REPL. Those live in the container.
- Auto-setup the runtime — explicit `/xspec:setup` keeps user in control.
