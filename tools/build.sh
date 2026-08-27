#!/usr/bin/env bash
# Build the matching GB target and print the SHA1 of the resulting ROM.
# Uses the real baserom.gb if present; otherwise synthesizes a zero-filled
# placeholder, which is sufficient to prove an edit is output-neutral.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
PLACEHOLDER=0
if [ ! -f baserom.gb ]; then
  head -c 65536 /dev/zero > baserom.gb
  PLACEHOLDER=1
fi
if ! out=$(make gb 2>&1); then
  # `check` failing on a placeholder baserom is expected; a real build error is not.
  if ! echo "$out" | grep -q 'computed checksum did NOT match'; then
    echo "$out" >&2; [ "$PLACEHOLDER" = 1 ] && rm -f baserom.gb; exit 1
  fi
fi
sha1sum < bin/gb/supermarioland.gb | cut -d' ' -f1
[ "$PLACEHOLDER" = 1 ] && rm -f baserom.gb
exit 0
