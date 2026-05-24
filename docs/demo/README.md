# Demo Recording Playbook

This directory hosts the materials for the README's `xspec` demo recording.

## Files

- `logistics-prompt.txt` — exact prose to type into the recorded Claude session
  during the demo. The bug we want Claude to seed (ship without recount
  precondition) is stated explicitly here so the demo is reproducible.

## How to record

1. Build runtime image if missing:
   ```
   docker build -t quint-runtime:0.1.0 \
     -f plugins/xspec/runtime/Dockerfile plugins/xspec/runtime/
   ```
2. Run the prep + record script:
   ```
   ./scripts/record-demo.sh
   ```
3. When asciinema prompts you to start recording, press Enter.
4. In the recorded shell, launch a sandboxed Claude:
   ```
   claude --settings /tmp/xspec-demo-settings.json \
          --plugin-dir <repo>/plugins/xspec \
          --model sonnet --effort medium
   ```
   (The script prints the exact command; copy-paste it.)
5. Once Claude is up: `/xspec:setup` (idempotent).
6. Type or paste the contents of `logistics-prompt.txt`.
7. Let the agent work. Approve permission dialogs as they come up
   (or pre-approve `docker exec quint-runtime *` once via "yes, don't ask again").
8. After the spec→verify→fix arc completes, exit Claude with `/exit`,
   then exit the recorded shell with Ctrl-D.
9. Trim dead air:
   ```
   ./scripts/trim-cast.sh /tmp/xspec-demo.cast
   ```
10. Sanity-play the trimmed cast:
    ```
    asciinema play /tmp/xspec-demo.trimmed.cast --speed 2
    ```
11. Upload to asciinema.org:
    ```
    asciinema upload /tmp/xspec-demo.trimmed.cast
    ```
    Capture the returned ID (the part after `/a/` in the URL).
12. Update the README embed:
    ```markdown
    [![demo](https://asciinema.org/a/<ID>.svg)](https://asciinema.org/a/<ID>?autoplay=1)
    ```

## What viewers should see

A ~90s arc:

1. `/xspec:setup` — runtime ready
2. Prompt is typed
3. Claude writes `specs/logistics.qnt` (~30 lines, reception/recount/ship actions, intentionally buggy ship)
4. `/xspec:verify:start` — random simulation finds a counterexample
5. `/xspec:verify:explain-trace` — counterexample narrated in plain English
6. Claude edits the spec to fix the bug (adds parts-match precondition to ship)
7. `/xspec:verify:start` again — green

## Re-recording

Re-runs are nearly deterministic but Claude's stochastic output may produce
variations. Acceptable if the arc is preserved; re-record if a viewer would
miss the find-bug-fix moment.

## Cleanup

```
docker rm -f quint-runtime
rm -rf /tmp/xspec-demo /tmp/xspec-demo-settings.json /tmp/xspec-demo.cast /tmp/xspec-demo.trimmed.cast
```

Then recreate the container with the project workspace mounted if you want
to keep using `xspec` for development.
