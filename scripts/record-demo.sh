#!/usr/bin/env bash
# Records an xspec demo. Vanilla Claude (no statusline, no hooks, no global skills),
# isolated workdir, xspec plugin loaded directly via --plugin-dir.
#
# Usage:
#   scripts/record-demo.sh
#
# Output: /tmp/xspec-demo.cast (raw; run scripts/trim-cast.sh to post-edit)

set -euo pipefail

SANDBOX_DIR="/tmp/xspec-demo"
SANDBOX_SETTINGS="/tmp/xspec-demo-settings.json"
MARKETPLACE_SYMLINK="/tmp/xspec-marketplace"
CONTAINER_NAME="quint-runtime"
IMAGE_TAG="quint-runtime:0.1.0"
CAST_OUT="/tmp/xspec-demo.cast"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_DIR="$MARKETPLACE_SYMLINK/plugins/xspec"  # via symlink so recording path doesn't leak /Users/<name>/

echo "==> Pre-flight checks"
command -v asciinema >/dev/null || { echo "asciinema not installed"; exit 1; }
command -v docker >/dev/null || { echo "docker not installed"; exit 1; }
command -v claude >/dev/null || { echo "claude not installed"; exit 1; }
docker info >/dev/null 2>&1 || { echo "docker daemon not running"; exit 1; }
docker image inspect "$IMAGE_TAG" >/dev/null 2>&1 || { echo "image $IMAGE_TAG missing — build it first"; exit 1; }
[ -d "$PLUGIN_DIR" ] || { echo "plugin dir not found: $PLUGIN_DIR"; exit 1; }

echo "==> Preparing sandbox workdir $SANDBOX_DIR"
rm -rf "$SANDBOX_DIR"
mkdir -p "$SANDBOX_DIR/specs"
# Pre-place the demo spec (with intentional bug) so the demo skips
# the noisy spec-writing phase and focuses on verify → fix.
cp "$REPO_ROOT/docs/demo/warehouse.qnt" "$SANDBOX_DIR/specs/warehouse.qnt"

echo "==> Symlinking marketplace into /tmp so recording path is clean"
rm -f "$MARKETPLACE_SYMLINK"
ln -s "$REPO_ROOT" "$MARKETPLACE_SYMLINK"

echo "==> Writing minimal settings (disables statusline, hooks, auto-memory)"
cat > "$SANDBOX_SETTINGS" <<'EOF'
{
  "statusLine": {
    "type": "command",
    "command": ":",
    "padding": 0,
    "refreshInterval": 60000
  },
  "hooks": {},
  "alwaysThinkingEnabled": false,
  "agentPushNotifEnabled": false,
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
EOF

echo "==> Recreating container with sandbox mount"
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker run -d \
  --name "$CONTAINER_NAME" \
  -v "$SANDBOX_DIR":/workspace \
  -w /workspace \
  "$IMAGE_TAG" tail -f /dev/null >/dev/null

# Wait briefly for container to be responsive
sleep 1
docker exec "$CONTAINER_NAME" quint --version >/dev/null

echo "==> Ready to record."
echo "    Recording will save to: $CAST_OUT"
echo
echo "    In the recorded shell, type:"
echo "        export CLAUDE_CODE_HIDE_CWD=1"
echo "        export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1"
echo "        claude --settings $SANDBOX_SETTINGS \\"
echo "               --plugin-dir $PLUGIN_DIR \\"
echo "               --model sonnet --effort medium"
echo ""
echo "    (Welcome banner with username is hardcoded — redact in post-edit"
echo "     via: sed -i '' 's/Welcome back [A-Z][a-z]*!/Welcome back!/g' <cast>)"
echo
echo "    Then drive the demo (use docs/demo/logistics-prompt.txt)."
echo "    Exit claude with /exit, exit shell with Ctrl-D."
echo
echo "    Press ENTER to start asciinema."
read -r

cd "$SANDBOX_DIR"
PS1='$ ' asciinema rec --window-size 120x36 --command "bash --norc -i" "$CAST_OUT"

echo "==> Recording saved to $CAST_OUT"
echo "==> Next: scripts/trim-cast.sh $CAST_OUT  # remove dead air"
