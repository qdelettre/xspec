#!/usr/bin/env bash
# Trim dead-air (>THRESHOLD seconds between events) in an asciinema .cast file.
# Supports v3 format (deltas) and v2 format (absolute timestamps), auto-detected.
#
# Usage:
#   scripts/trim-cast.sh /tmp/xspec-demo.cast
#
# Output: /tmp/xspec-demo.trimmed.cast (alongside input)

set -euo pipefail

IN="${1:?usage: $0 <cast-file>}"
OUT="${IN%.cast}.trimmed.cast"
MAX_GAP=1.0    # seconds — clamp gaps >THRESHOLD to this
THRESHOLD=3.0  # seconds — gap size that triggers trim

command -v jq >/dev/null || { echo "jq required"; exit 1; }
[ -f "$IN" ] || { echo "input not found: $IN"; exit 1; }

# Read header to detect version
VERSION=$(head -n1 "$IN" | jq -r '.version // empty')
[ -n "$VERSION" ] || { echo "could not parse cast header"; exit 1; }

# Header passes through unchanged
head -n1 "$IN" > "$OUT"

if [ "$VERSION" = "3" ]; then
  # v3: each event line is [delta, type, data]. Just clamp delta per event.
  tail -n +2 "$IN" | jq -cs --argjson threshold "$THRESHOLD" --argjson maxgap "$MAX_GAP" '
    .[] | [
      (if .[0] > $threshold then $maxgap else .[0] end),
      .[1],
      .[2]
    ]
  ' >> "$OUT"

  ORIG_LEN=$(tail -n +2 "$IN" | jq -s 'map(.[0]) | add')
  NEW_LEN=$(tail -n +2 "$OUT" | jq -s 'map(.[0]) | add')

elif [ "$VERSION" = "2" ]; then
  # v2: each event line is [absolute_t, type, data]. Walk in order, rewrite t.
  tail -n +2 "$IN" | jq -cs --argjson threshold "$THRESHOLD" --argjson maxgap "$MAX_GAP" '
    reduce .[] as $event (
      {prev_in_t: 0, out_t: 0, events: []};
      ($event[0] - .prev_in_t) as $delta
      | (if $delta > $threshold then $maxgap else $delta end) as $adjusted
      | (.out_t + $adjusted) as $new_out_t
      | {
          prev_in_t: $event[0],
          out_t: $new_out_t,
          events: (.events + [[$new_out_t, $event[1], $event[2]]])
        }
    )
    | .events[]
  ' >> "$OUT"

  ORIG_LEN=$(tail -n1 "$IN" | jq '.[0]')
  NEW_LEN=$(tail -n1 "$OUT" | jq '.[0]')

else
  echo "unsupported asciinema cast version: $VERSION"
  exit 1
fi

printf "Version:         %s\n" "$VERSION"
printf "Original length: %.2fs\n" "$ORIG_LEN"
printf "Trimmed length:  %.2fs\n" "$NEW_LEN"
echo "Output: $OUT"
