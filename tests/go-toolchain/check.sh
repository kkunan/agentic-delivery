#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/../lib.sh"
top=$(cd "$here/../.." && pwd -P)
[ $# -eq 1 ] || { echo "usage: tests/go-toolchain/check.sh <empty work folder>" >&2; exit 2; }
command -v go > /dev/null || { echo "check: go is not on PATH" >&2; exit 2; }
mkdir -p "$1" && work=$(cd "$1" && pwd -P) || exit 2
app="$work/sample"
ev="$work/evidence"
runner="$top/skills/platform-go/mutation-runner.sh"
mkdir -p "$ev"

say() {
    printf '\n== %s\n' "$*"
}

entries() {
    python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); print(str(d["compiled"]) + " " + " ".join(t["id"] + "=" + t["result"] for t in d["tests"]))' "$1" 2>/dev/null || echo "(no result file)"
}

# ── The sample module ─────────────────────────────────────────────────────

go version | tee "$ev/go-version.txt"
cp -R "$top/tests/go-module" "$app"
mkdir -p "$app/.claude"
printf -- '---\ngo_command: go\n---\n' > "$app/.claude/agentic-delivery.md"
git -C "$app" init -q
git -C "$app" add -A
git -C "$app" -c user.name=ci -c user.email=ci@example.test commit -q -m sample

# ── The commands of the skill ─────────────────────────────────────────────

say "go test, go vet, gofmt"
rc=0; (cd "$app" && go test -count=1 ./... > "$ev/test.log" 2>&1) || rc=$?
check "go test: exit 0" 0 "$rc"
rc=0; (cd "$app" && go vet ./... > "$ev/vet.log" 2>&1) || rc=$?
check "go vet: exit 0" 0 "$rc"
check "gofmt through go run: lists nothing" "" "$(cd "$app" && go run cmd/gofmt -l . 2> "$ev/gofmt.err")"
printf 'package sample\nfunc  Bad( ) int { return 1 }\n' > "$app/bad.go"
check "gofmt through go run: lists a bad file" "bad.go" "$(cd "$app" && go run cmd/gofmt -l . 2>> "$ev/gofmt.err")"
rm "$app/bad.go"

# ── The runner ────────────────────────────────────────────────────────────

say "runner"
(cd "$app" && "$runner" --out "$ev/ids.json" --log "$ev/ids.log" -- .::TestAdd .::TestClamp/low .::TestMissing < /dev/null)
check "runner: entries" "True .::TestAdd=passed .::TestClamp/low=passed" "$(entries "$ev/ids.json")"

cp "$app/calc.go" "$work/calc.go.orig"
printf 'func Broken() int { return "x" }\n' >> "$app/calc.go"
(cd "$app" && go test -json -count=1 . > "$ev/build-fail.jsonl" 2>&1)
(cd "$app" && "$runner" --out "$ev/broken.json" --log "$ev/broken.log" -- .::TestAdd < /dev/null)
check "runner: a build failure is not compiled" "False " "$(entries "$ev/broken.json")"
cp "$work/calc.go.orig" "$app/calc.go"

# ── Through mutate.sh ─────────────────────────────────────────────────────

say "mutate.sh"
cat > "$work/manifest.json" <<'EOF'
[
 {"label": "survives", "file": "calc.go", "find": "return hi", "replace": "return lo", "test": ".::TestClamp"},
 {"label": "killed", "file": "calc.go", "find": "return a + b", "replace": "return a - b", "test": ".::TestAdd"},
 {"label": "nocompile", "file": "calc.go", "find": "return a + b", "replace": "return a + \"b\"", "test": ".::TestAdd"}
]
EOF
rc=0
(cd "$app" && "$top/scripts/mutate.sh" --manifest "$work/manifest.json" --out "$ev/mutate" --runner "$runner" > "$ev/mutate.out" 2> "$ev/mutate.err") || rc=$?
cat "$ev/mutate.out"
check "mutate: exit 1, one survivor" 1 "$rc"
check "mutate: verdicts" "survived survives
killed killed
did-not-compile nocompile" "$(awk 'NR >= 2 && NR <= 4 { print $1, $2 }' "$ev/mutate.out")"
check "mutate: tree clean" "" "$(cd "$app" && git status --porcelain)"

finish
