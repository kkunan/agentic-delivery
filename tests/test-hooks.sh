#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/lib.sh"
root=$(cd "$here/.." && pwd -P)
start="$root/hooks/session-start.sh"
retro="$root/hooks/retro-notice.sh"

work=$(mktemp -d)
fake=$(mktemp -d)
private=$(mktemp -d)
plain=$(mktemp -d)
git -C "$work" init -q
mkdir -p "$work/.claude"
proj="$work/.claude/agentic-delivery.md"

text_of() {
    python3 -c 'import json,sys; d=json.loads(sys.stdin.read())["hookSpecificOutput"]; print(d["additionalContext"])'
}
event_of() {
    python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["hookSpecificOutput"]["hookEventName"])'
}
has() {
    case $1 in
        *"$2"*) echo yes ;;
        *) echo no ;;
    esac
}
payload() {
    python3 -c 'import json,sys; print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": sys.argv[1]}}))' "$1"
}

check "hooks.json is valid JSON" 0 "$(python3 -m json.tool "$root/hooks/hooks.json" >/dev/null 2>&1; echo $?)"
check "hooks.json wires SessionStart" "startup|clear|compact bash \"\${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh\"" \
    "$(python3 -c 'import json,sys; h=json.load(open(sys.argv[1]))["hooks"]["SessionStart"][0]; print(h["matcher"], h["hooks"][0]["command"])' "$root/hooks/hooks.json")"
check "hooks.json wires PostToolUse" "Write|Edit bash \"\${CLAUDE_PLUGIN_ROOT}/hooks/retro-notice.sh\"" \
    "$(python3 -c 'import json,sys; h=json.load(open(sys.argv[1]))["hooks"]["PostToolUse"][0]; print(h["matcher"], h["hooks"][0]["command"])' "$root/hooks/hooks.json")"
for s in session-start retro-notice; do
    check "$s is executable" yes "$([ -x "$root/hooks/$s.sh" ] && echo yes || echo no)"
    check "$s starts with a bash line" "#!/bin/bash" "$(head -n 1 "$root/hooks/$s.sh")"
done

cd "$work"
out=$(bash "$start"); check "start: no project file gives no output" "" "$out"
bash "$start" >/dev/null 2>&1; check "start: no project file exits 0" 0 $?
cd "$plain"
out=$(bash "$start"); check "start: outside a repository gives no output" "" "$out"
bash "$start" >/dev/null 2>&1; check "start: outside a repository exits 0" 0 $?
cd "$work"

printf -- '---\nplatform: flutter\nmin_plugin_version: 0.1.0\ndocs_dir: docs/features\n---\n# notes\n' > "$proj"
out=$(bash "$start")
check "start: normal file is valid JSON" 0 "$(printf '%s' "$out" | python3 -m json.tool >/dev/null 2>&1; echo $?)"
check "start: event name" SessionStart "$(printf '%s' "$out" | event_of)"
text=$(printf '%s' "$out" | text_of)
check "start: text is at most 600 characters" yes "$([ "${#text}" -le 600 ] && echo yes || echo no)"
check "start: text names the feature command" yes "$(has "$text" "/feature")"
check "start: text names controller" yes "$(has "$text" "controller")"
check "start: text names run-rules" yes "$(has "$text" "run-rules")"
check "start: text names the platform skill" yes "$(has "$text" "platform-flutter")"
check "start: text has no warning" no "$(has "$text" "is older than")"
check "start: text names the plugin scripts folder" yes "$(has "$text" "scripts/ means the folder $root/scripts, not a folder in the project.")"
bash "$start" >/dev/null 2>&1; check "start: normal file exits 0" 0 $?

printf -- '---\nplatform: flutter\nmin_plugin_version: 9.0.0\n---\n' > "$proj"
text=$(bash "$start" | text_of)
want="agentic-delivery $(jq -r .version "$root/.claude-plugin/plugin.json") is older than this project needs (9.0.0). Update the plugin."
check "start: older plugin warns first" "$want" "${text:0:${#want}}"
check "start: warning plus pointer is at most 600 characters" yes "$([ "${#text}" -le 600 ] && echo yes || echo no)"
check "start: warning text still names the skills" yes "$(has "$text" "platform-flutter")"
check "start: warning text still names the plugin scripts folder" yes "$(has "$text" "$root/scripts")"

printf -- '---\nplatform: flutter\n---\n' > "$proj"
text=$(bash "$start" | text_of)
check "start: no min_plugin_version gives no warning" no "$(has "$text" "is older than")"

printf -- '---\nplatform: dart\nmin_plugin_version: 0.1.0\n---\n' > "$proj"
text=$(bash "$start" | text_of)
check "start: the platform value names the skill" yes "$(has "$text" "platform-dart")"

printf -- '---\nmin_plugin_version: 0.1.0\n---\n' > "$proj"
text=$(bash "$start" | text_of)
check "start: no platform key asks for the empty keys" yes "$(has "$text" "has no platform")"
check "start: no platform key names no platform skill" no "$(has "$text" "platform-")"
bash "$start" >/dev/null 2>&1; check "start: no platform key exits 0" 0 $?

printf -- '---\nplatform:\nmin_plugin_version: 0.1.0\n---\n' > "$proj"
text=$(bash "$start" | text_of)
check "start: an empty platform asks for the empty keys" yes "$(has "$text" "has no platform")"

mkdir -p "$fake/hooks" "$fake/scripts" "$fake/.claude-plugin"
cp "$start" "$fake/hooks/session-start.sh"
cp "$root/scripts/project-config.sh" "$fake/scripts/project-config.sh"
printf '{"name": "agentic-delivery", "version": "0.10.0"}\n' > "$fake/.claude-plugin/plugin.json"
printf -- '---\nplatform: flutter\nmin_plugin_version: 0.9.0\n---\n' > "$proj"
text=$(bash "$fake/hooks/session-start.sh" | text_of)
check "start: 0.10.0 is not older than 0.9.0" no "$(has "$text" "is older than")"
printf -- '---\nplatform: flutter\nmin_plugin_version: 0.11.0\n---\n' > "$proj"
text=$(bash "$fake/hooks/session-start.sh" | text_of)
want="agentic-delivery 0.10.0 is older than this project needs (0.11.0). Update the plugin."
check "start: 0.10.0 is older than 0.11.0" "$want" "${text:0:${#want}}"
printf -- '---\nplatform: flutter\nmin_plugin_version: next\n---\n' > "$proj"
text=$(bash "$fake/hooks/session-start.sh" | text_of)
check "start: a min version that is not numeric gives no warning" no "$(has "$text" "is older than")"
rm -f "$fake/.claude-plugin/plugin.json"
printf -- '---\nplatform: flutter\nmin_plugin_version: 0.9.0\n---\n' > "$proj"
text=$(bash "$fake/hooks/session-start.sh" | text_of)
check "start: no plugin version gives no warning" no "$(has "$text" "is older than")"

rm -f "$proj"
out=$(payload "$work/docs/superpowers/retros/2026-01-01-x.md" | bash "$retro")
check "retro: docs/superpowers/retros path works with no project file" PostToolUse "$(printf '%s' "$out" | event_of)"
text=$(printf '%s' "$out" | text_of)
check "retro: notice says pull request" yes "$(has "$text" "pull request")"
check "retro: notice says plugin repository" yes "$(has "$text" "plugin repository")"
out=$(payload "$work/src/main.dart" | bash "$retro"); check "retro: no project file, source path gives nothing" "" "$out"

printf -- '---\nplatform: flutter\ndocs_dir: docs/features\n---\n' > "$proj"
out=$(payload "$work/docs/features/retros/2026-01-01-x.md" | bash "$retro")
check "retro: relative docs_dir retros path gives the notice" PostToolUse "$(printf '%s' "$out" | event_of)"
check "retro: the notice is valid JSON" 0 "$(printf '%s' "$out" | python3 -m json.tool >/dev/null 2>&1; echo $?)"
out=$(payload "$work/docs/features/2026-01-01-x/ledger.md" | bash "$retro"); check "retro: docs_dir ledger path gives nothing" "" "$out"
out=$(payload "$work/docs/features/retros-old/x.md" | bash "$retro"); check "retro: a folder that only starts like retros gives nothing" "" "$out"
out=$(payload "$work/docs/features/retros/../ledger.md" | bash "$retro"); check "retro: a path that climbs out of retros gives nothing" "" "$out"
out=$(payload "$work/src/main.dart" | bash "$retro"); check "retro: source path gives nothing" "" "$out"
out=$(payload "$work/docs/superpowers/retros/x.md" | bash "$retro")
check "retro: docs/superpowers/retros path still matches with a project file" PostToolUse "$(printf '%s' "$out" | event_of)"
out=$(printf '%s' 'not json' | bash "$retro"); check "retro: bad JSON gives nothing" "" "$out"
printf '%s' 'not json' | bash "$retro" >/dev/null 2>&1; check "retro: bad JSON exits 0" 0 $?
out=$(printf '%s' '{"tool_input": {}}' | bash "$retro"); check "retro: no file_path gives nothing" "" "$out"
out=$(printf '%s' '[1]' | bash "$retro"); check "retro: JSON that is not an object gives nothing" "" "$out"
out=$(bash "$retro" < /dev/null); check "retro: empty stdin gives nothing" "" "$out"
out=$(printf '%s' '{"tool_input": {"file_path": 5}}' | bash "$retro"); check "retro: a file_path that is not text gives nothing" "" "$out"

printf -- '---\nplatform: flutter\ndocs_dir: %s\n---\n' "$private" > "$proj"
out=$(payload "$private/retros/2026-01-01-x.md" | bash "$retro")
check "retro: absolute docs_dir retros path gives the notice" PostToolUse "$(printf '%s' "$out" | event_of)"
out=$(payload "$private/2026-01-01-x/ledger.md" | bash "$retro"); check "retro: absolute docs_dir ledger path gives nothing" "" "$out"
payload "$work/docs/superpowers/retros/x.md" | bash "$retro" >/dev/null 2>&1; check "retro: matching path exits 0" 0 $?

printf -- '---\nplatform: flutter\ndocs_dir: ~/%s\n---\n' "$(basename "$private")" > "$proj"
out=$(payload "$private/retros/2026-01-01-x.md" | HOME=$(dirname "$private") bash "$retro")
check "retro: a docs_dir under ~/ gives the notice" PostToolUse "$(printf '%s' "$out" | event_of)"

rm -f "$proj" "$fake/hooks/session-start.sh" "$fake/scripts/project-config.sh"
rmdir "$work/.claude" "$fake/hooks" "$fake/scripts" "$fake/.claude-plugin" "$fake" "$private" "$plain"
rm -rf "$work/.git"; rmdir "$work"
finish
