# Syncing Vendored Content from Upstream

This document tells Claude how to keep `plugins/xspec/` content fresh against
the upstream source at `https://github.com/quint-co/quint-llm-kit`.

The current synced baseline is the SHA in `.upstream-sha` at the repo root.
After every successful sync, that file is updated to the new upstream SHA.

---

## What's vendored

| Our path | Upstream path | Notes |
|---|---|---|
| `plugins/xspec/agents/*.md` | `agentic/agents/*.md` | Path rewrites + docker-exec prefix + Co-Authored-By removal |
| `plugins/xspec/commands/{spec,verify,code,refactor}/*.md` | `agentic/commands/{spec,verify,code,refactor}/*.md` | Path rewrites + command namespace + docker-exec prefix + PLUGIN_DIR injection |
| `plugins/xspec/references/*.md` (except `runtime-conventions.md`) | `agentic/guidelines/*.md` | Path rewrites + docker-exec prefix + command namespace |
| `plugins/xspec/schemas/*.json` | `agentic/schemas/*.json` | No adaptation, pure copy |
| `plugins/xspec/scripts/**` | `agentic/scripts/**` | No adaptation, pure copy |

`plugins/xspec/references/runtime-conventions.md`, `plugins/xspec/commands/{setup,teardown,status}.md`, and `plugins/xspec/skills/xspec/SKILL.md` are **authored by us**, not vendored. Do not overwrite these during sync.

`plugins/xspec/runtime/Dockerfile` is a heavy fork — handled separately, not by this procedure (see Dockerfile section below).

## When to run this procedure

1. CI weekly cron opens a `upstream-drift` issue → run sync.
2. User asks for an explicit sync.
3. You notice a bug in an agent/command/reference that may already be fixed upstream → run sync to pull in the fix.

## Procedure

### Step 1: Read current baseline

```bash
PINNED_SHA=$(cat .upstream-sha)
echo "Pinned at: $PINNED_SHA"
```

### Step 2: Fetch upstream HEAD SHA

```bash
NEW_SHA=$(gh api repos/quint-co/quint-llm-kit/commits/main --jq .sha)
echo "Upstream HEAD: $NEW_SHA"

if [ "$PINNED_SHA" = "$NEW_SHA" ]; then
  echo "Already in sync. Nothing to do."
  exit 0
fi
```

### Step 3: List changed files in upstream agentic between pinned and HEAD

```bash
gh api "repos/quint-co/quint-llm-kit/compare/${PINNED_SHA}...${NEW_SHA}" \
  --jq '.files[].filename' \
  | grep '^agentic/' \
  | tee /tmp/upstream-drift.txt
```

Review the list. For each path, categorize:

- `agentic/agents/*.md` → vendored, needs adaptation
- `agentic/commands/{spec,verify,code,refactor}/*.md` → vendored, needs adaptation
- `agentic/guidelines/*.md` → vendored as references, needs adaptation
- `agentic/schemas/*.json` → vendored, pure copy
- `agentic/scripts/**` → vendored, pure copy
- `agentic/commands/setup.md` / `teardown.md` / `status.md` at top level → upstream doesn't ship these; if upstream adds them, treat as new — confirm with user before vendoring (we have our own lifecycle commands).
- New paths in `agentic/` not listed above → escalate to user.

### Step 4: Fetch + adapt each changed file

For each `agentic/<path>` in the drift list:

```bash
# Resolve our local path
case "$path" in
  agentic/agents/*.md)
    LOCAL="plugins/xspec/agents/$(basename "$path")"
    KIND="adapt-md"
    ;;
  agentic/commands/spec/*.md|agentic/commands/verify/*.md|agentic/commands/code/*.md|agentic/commands/refactor/*.md)
    SUBDIR=$(dirname "$path" | sed 's|agentic/commands/||')
    LOCAL="plugins/xspec/commands/$SUBDIR/$(basename "$path")"
    KIND="adapt-md"
    ;;
  agentic/guidelines/*.md)
    LOCAL="plugins/xspec/references/$(basename "$path")"
    KIND="adapt-md"
    ;;
  agentic/schemas/*.json)
    LOCAL="plugins/xspec/schemas/$(basename "$path")"
    KIND="copy"
    ;;
  agentic/scripts/*)
    REL=$(echo "$path" | sed 's|agentic/scripts/||')
    LOCAL="plugins/xspec/scripts/$REL"
    KIND="copy"
    ;;
esac

# Fetch fresh upstream content
gh api "repos/quint-co/quint-llm-kit/contents/${path}?ref=${NEW_SHA}" \
  --jq '.content' | base64 -d > "$LOCAL"

# If KIND=adapt-md, apply adaptation rules (see below)
# If KIND=copy, nothing more to do
```

### Step 5: Apply adaptation rules to `.md` files

For every `.md` file fetched in Step 4 with KIND=adapt-md, run these rules in order.

#### Rule 5a — Mechanical: path rewrites

```bash
sed -i '' \
  -e 's|@\.claude/guidelines/|@references/|g' \
  -e 's|\.claude/guidelines/|references/|g' \
  -e 's|@\.claude/agents/|@agents/|g' \
  -e 's|\.claude/agents/|agents/|g' \
  -e 's|@\.claude/schemas/|@schemas/|g' \
  -e 's|\.claude/schemas/|schemas/|g' \
  -e 's|@\.claude/scripts/|@scripts/|g' \
  -e 's|\.claude/scripts/|scripts/|g' \
  "$LOCAL"
```

#### Rule 5b — Mechanical: command namespace

```bash
# Frontmatter command: field
sed -i '' \
  -e 's|^command: /quint:|command: /xspec:|g' \
  -e 's|^command: /spec:|command: /xspec:spec:|g' \
  -e 's|^command: /verify:|command: /xspec:verify:|g' \
  -e 's|^command: /code:|command: /xspec:code:|g' \
  -e 's|^command: /refactor:|command: /xspec:refactor:|g' \
  "$LOCAL"

# Body references. Apply /quint: first to avoid touching the newly-rewritten
# /xspec:spec: form via the /spec: rule.
sed -i '' \
  -e 's|/quint:|/xspec:|g' \
  -e 's|/spec:|/xspec:spec:|g' \
  -e 's|/verify:|/xspec:verify:|g' \
  -e 's|/code:|/xspec:code:|g' \
  -e 's|/refactor:|/xspec:refactor:|g' \
  "$LOCAL"
```

#### Rule 5c — Mechanical: image tag (defensive)

```bash
sed -i '' 's|quint-marketplace-runtime|quint-runtime|g' "$LOCAL"
```

#### Rule 5d — Judgment: docker-exec prefix on bash quint calls

Inspect the file. Look for lines matching:

```
^[[:space:]]*quint[[:space:]]+(typecheck|run|verify|test|parse|repl|compile)
```

For each match:
- If inside a bash code fence (```` ```bash ... ``` ````), prefix with `docker exec quint-runtime `.
- If in prose (e.g., "the `quint verify` command does X"), DO NOT prefix.
- If inside a Quint code fence (```` ```quint ... ``` ````), DO NOT prefix (it's spec source, not a shell command).

Use Read + Edit tools to apply per-occurrence.

#### Rule 5e — Judgment: PLUGIN_DIR injection on python3 script invocations

Inspect the file. Look for lines matching:

```
^[[:space:]]*python3[[:space:]]+scripts/
```

Inside bash code fences. Rewrite as:

```bash
PLUGIN_DIR="$(find ~/.claude -type d -name xspec -path '*plugins/xspec*' 2>/dev/null | head -1)"
python3 "$PLUGIN_DIR/scripts/<original-relative-path>" <args>
```

Skip prose mentions.

#### Rule 5f — Judgment: Co-Authored-By removal

```bash
grep -in 'co-authored' "$LOCAL"
```

For each match: if the surrounding text instructs the agent to add a Co-Authored-By trailer to commits, remove the trailer-instruction line(s). Use Edit tool. Skip if the mention is purely descriptive (e.g., "git supports Co-Authored-By trailers" with no instruction to add).

### Step 6: Sanity sweep

```bash
grep -rn '\.claude/' plugins/xspec/ && echo "STALE_PATHS" || echo "PATHS_OK"
grep -rn '^command: /quint:\|^command: /spec:\|^command: /verify:\|^command: /code:\|^command: /refactor:' plugins/xspec/commands/ && echo "STALE_NAMESPACE" || echo "NAMESPACE_OK"
grep -rn 'quint-marketplace' . --include='*.json' --include='*.yml' --include='*.md' --include='Dockerfile' | grep -v '.git' && echo "STALE_NAME" || echo "NAME_OK"
```

All three must report OK. If any STALE_*, fix and rerun.

### Step 7: Smoke test through the runtime

Ensure container is running:

```bash
docker ps --filter name=^quint-runtime$ -q | grep . || (echo "Start container first via /xspec:setup or docker run"; exit 1)
```

Run bank fixture:

```bash
docker exec quint-runtime quint typecheck tests/fixtures/bank.qnt && echo TYPECHECK_OK
docker exec quint-runtime quint run --invariant=safe --max-samples=100 --max-steps=20 tests/fixtures/bank.qnt 2>&1 | grep -E '^\[(ok|violation)\]'
```

Expected: TYPECHECK_OK, then `[ok] No violation found ...`.

If smoke fails: investigate. Might be a sync regression. Revert problematic files and escalate.

### Step 8: Update `.upstream-sha`

```bash
echo "$NEW_SHA" > .upstream-sha
cat .upstream-sha
```

### Step 9: Commit

```bash
git add -A
git commit -m "sync: upstream agentic content to ${NEW_SHA:0:7}

Synced files:
$(cat /tmp/upstream-drift.txt | sed 's/^/  - /')

Baseline: ${PINNED_SHA} → ${NEW_SHA}"
```

No Co-Authored-By trailer (project policy).

### Step 10: Close the drift issue if CI opened one

```bash
gh issue list --label upstream-drift --state open --json number --jq '.[].number' \
  | xargs -I{} gh issue close {} --comment "Synced in $(git rev-parse --short HEAD). Baseline now $(cat .upstream-sha | cut -c1-7)."
```

(Skip if no issue exists.)

## Handling structural upstream changes

### New file in an existing upstream dir

1. Fetch + adapt + place in the corresponding local dir.
2. If the file uses idioms not covered by Rules 5a-5f, add the new rule to this document, then apply.

### Removed upstream file

1. Stop. Confirm with user.
2. Options: keep our copy as permanent fork; delete from our repo; preserve under a different name.

### Renamed upstream file

1. Detect via `gh api .../compare/...` showing both add + delete in the same diff.
2. Confirm rename with user (it's heuristic, sometimes upstream genuinely deletes + adds unrelated files).
3. If confirmed: `git mv` our local file to the new path, then apply Rules 5a-5f.

### New upstream directory

1. Stop. Confirm with user.
2. Decide whether to vendor (and how), or ignore.

### Restructure (e.g., upstream splits agentic/ into versioned subdirs)

1. Stop. Escalate to user.
2. May need a fresh design pass on our side.

## Updating this procedure document

When you apply a new adaptation type during a sync that's not covered by Rules 5a-5f, add it as a new Rule 5x section with:

1. What pattern to look for
2. What transform to apply
3. When to skip (prose vs. exec line distinctions)

Commit the SYNCING.md update in the same commit as the sync that surfaced it.

## Dockerfile (out of scope here)

The `plugins/xspec/runtime/Dockerfile` is a heavy fork of upstream's `claudecode.dockerfile` with stripped Claude Code layers, OCI LABELs, and a pinned `mcp-language-server` SHA. It does not change often upstream, and re-forking is judgment-heavy.

When upstream's `claudecode.dockerfile` materially changes (e.g., new toolchain, new Quint version pin), perform an ad-hoc re-fork by hand. Diff upstream's new Dockerfile against the version we forked from, decide which changes to incorporate, reapply our strips + adds. This is rare (months apart) and warrants a manual review session rather than scripted sync.

## Quick reference

| Action | Command |
|---|---|
| Check current pin | `cat .upstream-sha` |
| Check upstream HEAD | `gh api repos/quint-co/quint-llm-kit/commits/main --jq .sha` |
| Find drift | `gh api "repos/quint-co/quint-llm-kit/compare/$(cat .upstream-sha)...main" --jq '.files[].filename' \| grep '^agentic/'` |
| Sanity check after sync | `grep -rn '\.claude/' plugins/xspec/ && echo STALE \|\| echo OK` |
| Smoke test | `docker exec quint-runtime quint typecheck tests/fixtures/bank.qnt` |
