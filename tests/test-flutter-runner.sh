#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/lib.sh"
top=$(cd "$here/.." && pwd -P)
runner="$top/skills/platform-flutter/mutation-runner.sh"
mutate="$top/scripts/mutate.sh"
flutter=${FLUTTER_BIN:-$(command -v flutter)}
[ -n "$flutter" ] || { echo "SKIP flutter runner: no flutter on PATH and FLUTTER_BIN is not set"; exit 0; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export TMPDIR="$work/tmp"
mkdir "$TMPDIR"
app="$work/app"

field() {
    python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2" 2>/dev/null || echo "(no result file)"
}

run() {
    name=$1
    shift
    rc=0
    (cd "$app" && "$runner" --out "$work/$name.json" --log "$work/$name.log" -- "$@" < /dev/null 2>/dev/null) || rc=$?
}

# ── A scratch app ─────────────────────────────────────────────────────────

"$flutter" create --offline --platforms web --project-name runner_check "$app" > "$work/create.log" 2>&1
check "flutter create" 0 $?
cat > "$app/lib/calc.dart" <<'EOF'
int add(int a, int b) => a + b;

int twice(int a) => a * 2;
EOF
cat > "$app/test/calc_test.dart" <<'EOF'
import 'package:flutter_test/flutter_test.dart';

import 'package:runner_check/calc.dart';

void main() {
  test('add', () {
    expect(add(2, 3), 5);
  });

  test('add twice', () {
    expect(twice(add(1, 1)), 4);
  });

  test('skipped one', () {}, skip: true);

  group('Calc', () {
    test('twice doubles', () {
      expect(twice(4), 8);
    });
  });
}
EOF
rm -f "$app/test/widget_test.dart"
cp "$app/lib/calc.dart" "$work/calc.dart"
(cd "$app" && git init -q . && git add -A && git -c user.name=check -c user.email=check@example.invalid -c commit.gpgsign=false commit -qm app)
check "git commit of the app" 0 $?

# ── Direct calls ──────────────────────────────────────────────────────────

run pass 'test/calc_test.dart::add'
check "pass: exit 0" 0 "$rc"
check "pass: one entry, passed" "True [{'id': 'test/calc_test.dart::add', 'result': 'passed'}]" "$(field "$work/pass.json" 'str(d["compiled"]) + " " + str(d["tests"])')"
check "pass: the substring match ran another test" yes "$(grep -q 'add twice' "$work/pass.log" && echo yes || echo no)"

run two 'test/calc_test.dart::add twice' 'test/calc_test.dart::Calc twice doubles'
check "two ids: exit 0" 0 "$rc"
check "two ids: both passed" "test/calc_test.dart::add twice=passed test/calc_test.dart::Calc twice doubles=passed" "$(field "$work/two.json" '" ".join(t["id"] + "=" + t["result"] for t in d["tests"])')"

run absent 'test/calc_test.dart::no such test'
check "absent name: no entry" "True []" "$(field "$work/absent.json" 'str(d["compiled"]) + " " + str(d["tests"])')"

run nofile 'test/nope_test.dart::add'
check "absent file: no entry" "True []" "$(field "$work/nofile.json" 'str(d["compiled"]) + " " + str(d["tests"])')"

run skipped 'test/calc_test.dart::skipped one'
check "skipped" skipped "$(field "$work/skipped.json" 'd["tests"][0]["result"]')"

run nocolon 'test/calc_test.dart'
check "no '::': exit 2" 2 "$rc"
check "no '::': no result file" no "$([ -e "$work/nocolon.json" ] && echo yes || echo no)"
check "no '::': the log says why" yes "$(grep -q "REFUSED: the test id 'test/calc_test.dart' has no '::'" "$work/nocolon.log" && echo yes || echo no)"

rc=0
(cd "$app" && "$runner" --out "$work/usage.json" -- 'test/calc_test.dart::add' < /dev/null > /dev/null 2>&1) || rc=$?
check "usage error: exit 2" 2 "$rc"

sed 's/a + b/a - b/' "$work/calc.dart" > "$app/lib/calc.dart"
run failed 'test/calc_test.dart::add'
check "broken code: failed" "True failed" "$(field "$work/failed.json" 'str(d["compiled"]) + " " + d["tests"][0]["result"]')"

sed 's/a + b/a + /' "$work/calc.dart" > "$app/lib/calc.dart"
run syntax 'test/calc_test.dart::add'
check "syntax error: compiled false" "False []" "$(field "$work/syntax.json" 'str(d["compiled"]) + " " + str(d["tests"])')"
cp "$work/calc.dart" "$app/lib/calc.dart"

# ── Through mutate.sh ─────────────────────────────────────────────────────

cat > "$work/list.json" <<'EOF'
[
 {"label": "survives", "file": "lib/calc.dart", "find": "a * 2", "replace": "a + a", "test": "test/calc_test.dart::Calc twice doubles"},
 {"label": "killed", "file": "lib/calc.dart", "find": "a + b", "replace": "a - b", "test": "test/calc_test.dart::add"},
 {"label": "nocompile", "file": "lib/calc.dart", "find": "a + b", "replace": "a + ", "test": "test/calc_test.dart::add"},
 {"label": "absent", "file": "test/calc_test.dart", "find": "test('add twice'", "replace": "test('add thrice'", "test": "test/calc_test.dart::add twice"}
]
EOF
rc=0
(cd "$app" && "$mutate" --runner "$runner" --manifest "$work/list.json" --out "$work/mutate" > "$work/mutate.out" 2> "$work/mutate.err") || rc=$?
check "mutate: exit 1" 1 "$rc"
check "mutate: verdicts" "survived survives
killed killed
did-not-compile nocompile
error absent" "$(awk 'NR >= 2 && NR <= 5 { print $1, $2 }' "$work/mutate.out")"
check "mutate: tree clean" "" "$(cd "$app" && git status --porcelain)"

finish
