#!/bin/bash
printf '%s\n' "$*" >> "$FAKE_CALLS"
pkg=${!#}
key=$(printf '%s' "$pkg" | tr -c 'A-Za-z0-9' '_')
[ -f "$FAKE_GO_DIR/$key.jsonl" ] && cat "$FAKE_GO_DIR/$key.jsonl"
exit "$(cat "$FAKE_GO_DIR/$key.rc" 2>/dev/null || echo 0)"
