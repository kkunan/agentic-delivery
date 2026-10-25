#!/bin/bash
printf '%s\n' "$*" >> "$FAKE_CALLS"
printf '%s\n' "$PWD" > "$FAKE_CALLS.pwd"
[ -n "${FAKE_FLAG:-}" ] && printf '%s\n' "$FAKE_FLAG" > "$FAKE_CALLS.env"
task=$1
key=$(printf '%s' "$task" | tr -c 'A-Za-z0-9' '_')
path=${task#:}
name=${path##*:}
module=.
case "$path" in *:*) module=$(printf '%s' "${path%:*}" | tr : /) ;; esac
if [ -f "$FAKE_GRADLE_DIR/$key.xml" ]; then
    mkdir -p "$module/build/test-results/$name"
    cp "$FAKE_GRADLE_DIR/$key.xml" "$module/build/test-results/$name/TEST-fake.xml"
fi
[ -f "$FAKE_GRADLE_DIR/$key.out" ] && cat "$FAKE_GRADLE_DIR/$key.out"
exit "$(cat "$FAKE_GRADLE_DIR/$key.rc" 2>/dev/null || echo 0)"
