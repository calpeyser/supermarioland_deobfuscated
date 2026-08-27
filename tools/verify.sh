#!/usr/bin/env bash
# Neutrality oracle. Compares the current tree's build against tools/.baseline.
# Usage:  tools/verify.sh --set   record the current build as the baseline
#         tools/verify.sh         assert the build still matches the baseline
set -euo pipefail
cd "$(dirname "$0")/.."
B=tools/.baseline
h=$(tools/build.sh)
if [ "${1:-}" = "--set" ]; then echo "$h" > "$B"; echo "baseline set: $h"; exit 0; fi
[ -f "$B" ] || { echo "no baseline; run tools/verify.sh --set" >&2; exit 2; }
want=$(cat "$B")
if [ "$h" = "$want" ]; then echo "OK  $h"; exec tools/check-symbols.py; fi
echo "CHANGED  built=$h  baseline=$want" >&2; exit 1
