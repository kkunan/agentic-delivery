#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/../lib.sh"
top=$(cd "$here/../.." && pwd -P)
[ $# -eq 1 ] || { echo "usage: tests/kmp-toolchain/check.sh <empty work folder>" >&2; exit 2; }
jdk=${KMP_CHECK_JAVA_HOME:-}
[ -n "$jdk" ] || { echo "check: set KMP_CHECK_JAVA_HOME to an arm64 JDK 17 or later" >&2; exit 2; }
chrome=${KMP_CHECK_CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}
[ -x "$jdk/bin/java" ] || { echo "check: no java in $jdk; set KMP_CHECK_JAVA_HOME to an arm64 JDK 17 or later" >&2; exit 2; }
"$jdk/bin/java" -XshowSettings:properties -version 2>&1 | grep -q 'os.arch = aarch64' || { echo "check: $jdk is not an arm64 JDK, and Kotlin/Native then skips the iOS simulator tests" >&2; exit 2; }
[ -x "$chrome" ] || { echo "check: no Chrome at $chrome; set KMP_CHECK_CHROME" >&2; exit 2; }
command -v swift > /dev/null || { echo "check: swift is not on PATH" >&2; exit 2; }
mkdir -p "$1" && work=$(cd "$1" && pwd -P) || exit 2
app="$work/sample"
ev="$work/evidence"
registry="$work/gradle-daemons"
runner="$top/skills/platform-kmp/mutation-runner.sh"
claim="$top/scripts/claim-device.sh"
settle="$top/scripts/settle-screenshot.swift"
[ -e "$app" ] && { echo "check: $app already exists; pass an empty work folder" >&2; exit 2; }
mkdir -p "$ev"
gradle_command="env JAVA_HOME=$(printf '%q' "$jdk") ./gradlew"
export GRADLE_OPTS="${GRADLE_OPTS:+$GRADLE_OPTS }-Dorg.gradle.daemon.registry.base=$registry"
port=""
server_pid=""
listeners=""
sampler_pid=""
limit_pid=""
watch_pid=""
profiles=()

start=$(date +%s)

say() {
    printf '\n== [%s s] %s\n' "$(($(date +%s) - start))" "$*"
}

step() {
    printf '   [%s s] %s\n' "$(($(date +%s) - start))" "$*"
}

note() {
    printf 'NOTE %s\n' "$*" | tee -a "$ev/notes.txt"
}

limit() {
    local seconds=$1 dir=$2 rc
    shift 2
    (cd "$dir" && exec "$@") &
    limit_pid=$!
    perl -e 'sleep $ARGV[0]; print STDERR "TIME LIMIT: $ARGV[0] s passed; stopping $ARGV[2]\n"; kill "TERM", $ARGV[1]' "$seconds" "$limit_pid" "$1" &
    watch_pid=$!
    wait "$limit_pid"
    rc=$?
    kill "$watch_pid" 2>/dev/null
    wait "$watch_pid" 2>/dev/null
    limit_pid=""
    watch_pid=""
    return "$rc"
}

measure() {
    local name=$1 seconds=$2 shown=$3 t0 rc took
    shift 3
    step "$name: $shown"
    t0=$(date +%s)
    limit "$seconds" "$app" "$@" > "$ev/$name.log" 2>&1 < /dev/null
    rc=$?
    took=$(($(date +%s) - t0))
    printf 'exit %s, %s s\n' "$rc" "$took" > "$ev/$name.rc"
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$rc" "$took" "$ev/$name.log" "$shown" >> "$ev/summary.tsv"
    step "$name: exit $rc, $took s"
    return "$rc"
}

gradle() {
    local name=$1
    shift
    measure "$name" 1800 "$gradle_command $* --console=plain" bash -c "$gradle_command"' "$@"' gradle-command "$@" --console=plain
}

results() {
    python3 -c '
import glob, os, sys
import xml.etree.ElementTree as ET
n = failed = skipped = 0
names = []
for path in sorted(glob.glob(os.path.join(sys.argv[1], "TEST-*.xml"))):
    for case in ET.parse(path).getroot().iter("testcase"):
        tags = [c.tag for c in case]
        n += 1
        failed += "failure" in tags or "error" in tags
        skipped += "skipped" in tags
        names.append(case.get("name", ""))
print("tests=%d failed=%d skipped=%d" % (n, failed, skipped) if sys.argv[2] == "counts" else ", ".join(sorted(names)))
' "$1" "$2" 2>/dev/null || echo "(no report in $1)"
}

keep_results() {
    mkdir -p "$ev/test-results/$1"
    cp "$app/$2"/TEST-*.xml "$ev/test-results/$1/" 2>/dev/null
}

entry() {
    python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
if sys.argv[2] == "compiled":
    print(d["compiled"])
else:
    print(" ".join(t["result"] for t in d["tests"] if t["id"] == sys.argv[2]) or "absent")
' "$1" "$2" 2>/dev/null || echo "(no result file)"
}

frame_check() {
    python3 -c '
import struct, sys, zlib
data = open(sys.argv[1], "rb").read()
if data[:8] != b"\x89PNG\r\n\x1a\n":
    print("no: not a PNG"); sys.exit()
pos, idat = 8, b""
while pos < len(data):
    size, = struct.unpack(">I", data[pos:pos + 4])
    kind, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + size]
    pos += 12 + size
    if kind == b"IHDR":
        width, height, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
    elif kind == b"IDAT":
        idat += body
if depth != 8 or ctype not in (2, 6) or interlace:
    print("no: PNG depth %d, colour type %d, interlace %d is not handled" % (depth, ctype, interlace)); sys.exit()
bpp = 3 if ctype == 2 else 4
raw, stride = zlib.decompress(idat), width * bpp
prev, i, blue, white = bytearray(stride), 0, 0, 0
for y in range(height):
    kind, line = raw[i], bytearray(raw[i + 1:i + 1 + stride])
    i += 1 + stride
    for x in range(stride):
        a = line[x - bpp] if x >= bpp else 0
        b = prev[x]
        c = prev[x - bpp] if x >= bpp else 0
        if kind == 1:
            line[x] = (line[x] + a) & 255
        elif kind == 2:
            line[x] = (line[x] + b) & 255
        elif kind == 3:
            line[x] = (line[x] + (a + b) // 2) & 255
        elif kind == 4:
            p = a + b - c
            pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
            line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
    for x in range(0, stride, bpp):
        r, g, bl = line[x], line[x + 1], line[x + 2]
        if abs(r - 21) <= 3 and abs(g - 101) <= 3 and abs(bl - 192) <= 3:
            blue += 1
        elif r >= 240 and g >= 240 and bl >= 240:
            white += 1
    prev = line
share = blue / float(width * height)
verdict = "yes" if share >= 0.9 and white >= 100 else "no"
print("%s: %dx%d, %.3f of the pixels are 0x1565C0, %d white pixels" % (verdict, width, height, share, white))
' "$1" 2>&1
}

daemons() {
    ls "$registry"/*/daemon-*.out.log 2>/dev/null | sed -E 's/.*daemon-([0-9]+)\.out\.log$/\1/'
}

stop_pid() {
    local pid=$1 why=$2 i
    [ -n "$pid" ] || return 0
    ps -p "$pid" > /dev/null 2>&1 || return 0
    printf '%s %s %s\n' "$pid" "$(ps -o comm= -p "$pid")" "$why" >> "$ev/stopped-processes.log"
    kill "$pid" 2>/dev/null
    for i in 1 2 3 4 5 6 7 8 9 10; do
        ps -p "$pid" > /dev/null 2>&1 || return 0
        sleep 1
    done
    kill -9 "$pid" 2>/dev/null
}

descendants() {
    local child
    for child in $(pgrep -P "$1"); do
        descendants "$child"
        echo "$child"
    done
}

stop_tree() {
    local pid=$1 why=$2 child
    [ -n "$pid" ] || return 0
    for child in $(descendants "$pid"); do
        stop_pid "$child" "under $pid ($why)"
    done
    stop_pid "$pid" "$why"
}

stop_chrome() {
    local profile pid
    for profile in ${profiles[@]+"${profiles[@]}"}; do
        for pid in $(pgrep -f -- "--user-data-dir=$profile"); do
            stop_pid "$pid" "Chrome left over from $profile"
        done
    done
}

stop_server() {
    local pid
    [ -n "$server_pid" ] || return 0
    stop_tree "$server_pid" "Gradle client of the web run task"
    for pid in $listeners; do
        stop_pid "$pid" "web server left over after its Gradle client stopped"
    done
    server_pid=""
}

cleanup() {
    local d
    trap '' INT TERM
    stop_pid "$watch_pid" "time limit watchdog"
    stop_tree "$limit_pid" "command under the time limit"
    stop_server
    stop_chrome
    if [ -n "$port" ]; then
        bash "$claim" --device "web-$port" --worktree "$app" --release > /dev/null 2>&1
    fi
    for d in $(daemons); do
        ps -o command= -p "$d" 2>/dev/null | grep -q 'GradleDaemon' || continue
        stop_pid "$d" "Gradle daemon of this check"
    done
    stop_tree "$sampler_pid" "process sampler"
}
trap cleanup EXIT
trap 'printf "\nstopped by a signal\n"; exit 130' INT
trap 'printf "\nstopped by a signal\n"; exit 143' TERM

# ── The sample ────────────────────────────────────────────────────────────

say "sample"
mkdir -p "$app"
(cd "$top/tests/kmp-sample" && git ls-files -z | tar -cf - --null -T -) | (cd "$app" && tar -xf -)
mkdir -p "$app/.claude"
printf -- '---\ngradle_command: %s\n---\n' "$gradle_command" > "$app/.claude/agentic-delivery.md"
git -C "$app" init -q
git -C "$app" add -A
git -C "$app" -c user.name=ci -c user.email=ci@example.test -c commit.gpgsign=false commit -q -m sample
check "sample committed in its own repository" "$app" "$(git -C "$app" rev-parse --show-toplevel)"
cat "$app/.claude/agentic-delivery.md" > "$ev/project-file.txt"

(
    "$jdk/bin/java" -version 2>&1
    "$chrome" --version 2>&1
    xcodebuild -version 2>&1
    sw_vers 2>&1
    uname -m
) > "$ev/versions.txt"

(
    while :; do
        printf -- '-- %s\n' "$(date '+%H:%M:%S')"
        for name in java node webpack xcodebuild "Google Chrome"; do
            for pid in $(pgrep -x "$name"); do
                printf '%s %s\n' "$pid" "$name"
            done
        done
        sleep 5
    done
) > "$ev/processes.log" 2>&1 &
sampler_pid=$!

gradle gradle-version --version
check "gradle --version: exit 0" 0 $?

# ── 1. Build and tests of each target ─────────────────────────────────────

say "1. build and tests of each target"
gradle shared-jvm-test :shared:jvmTest
check "shared JVM tests: exit 0" 0 $?
keep_results shared-jvm-test shared/build/test-results/jvmTest
check "shared JVM tests: report" "tests=2 failed=0 skipped=0" "$(results "$app/shared/build/test-results/jvmTest" counts)"

gradle server-test :server:test
check "server tests: exit 0" 0 $?
keep_results server-test server/build/test-results/test
check "server tests: report" "tests=2 failed=0 skipped=0" "$(results "$app/server/build/test-results/test" counts)"

gradle shared-wasm-test :shared:wasmJsBrowserTest
check "shared Wasm browser tests: exit 0" 0 $?
keep_results shared-wasm-test shared/build/test-results/wasmJsBrowserTest
check "shared Wasm browser tests: report" "tests=2 failed=0 skipped=0" "$(results "$app/shared/build/test-results/wasmJsBrowserTest" counts)"

gradle shared-android-host-test :shared:testAndroidHostTest
check "shared Android host tests: exit 0" 0 $?
keep_results shared-android-host-test shared/build/test-results/testAndroidHostTest
check "shared Android host tests: report" "tests=2 failed=0 skipped=0" "$(results "$app/shared/build/test-results/testAndroidHostTest" counts)"

gradle android-debug-build :androidApp:assembleDebug
check "Android debug build: exit 0" 0 $?
check "Android debug build: APK" yes "$([ -s "$app/androidApp/build/outputs/apk/debug/androidApp-debug.apk" ] && echo yes || echo no)"

gradle shared-ios-test :shared:iosSimulatorArm64Test
check "shared iOS simulator tests: exit 0" 0 $?
keep_results shared-ios-test shared/build/test-results/iosSimulatorArm64Test
check "shared iOS simulator tests: no SKIPPED or disabled line" "" "$(grep -E '^> Task :shared:iosSimulatorArm64Test (SKIPPED|NO-SOURCE)|is disabled' "$ev/shared-ios-test.log")"
check "shared iOS simulator tests: report" "tests=2 failed=0 skipped=0" "$(results "$app/shared/build/test-results/iosSimulatorArm64Test" counts)"

gradle ios-framework-link :composeApp:linkDebugFrameworkIosSimulatorArm64
check "iOS framework link: exit 0" 0 $?
check "iOS framework link: framework" yes "$([ -d "$app/composeApp/build/bin/iosSimulatorArm64/debugFramework/ComposeApp.framework" ] && echo yes || echo no)"

# ── 2. The runner baseline ────────────────────────────────────────────────

say "2. runner baseline"
spaced=":server:test::trip.ServerTest.health answers ok for a plain request"
measure runner-baseline 1800 "mutation-runner.sh --out runner-baseline.json --log runner-baseline.runner.log -- <3 ids>" \
    "$runner" --out "$ev/runner-baseline.json" --log "$ev/runner-baseline.runner.log" -- \
    ":shared:jvmTest::trip.ClampTest.inside" ":server:test::trip.ServerTest.healthAnswersOk" "$spaced"
check "runner baseline: exit 0" 0 $?
keep_results runner-baseline-server server/build/test-results/test
check "runner baseline: compiled" True "$(entry "$ev/runner-baseline.json" compiled)"
check "runner baseline: ClampTest.inside" passed "$(entry "$ev/runner-baseline.json" ":shared:jvmTest::trip.ClampTest.inside")"
check "runner baseline: ServerTest.healthAnswersOk" passed "$(entry "$ev/runner-baseline.json" ":server:test::trip.ServerTest.healthAnswersOk")"
check "runner baseline: the name with spaces" passed "$(entry "$ev/runner-baseline.json" "$spaced")"
note "server cases that the baseline ran: $(results "$app/server/build/test-results/test" names)"

# ── 3. The runner verdicts through mutate.sh ──────────────────────────────

say "3. mutate.sh"
cat > "$work/manifest.json" <<'EOF'
[
 {"label": "hi-survives", "file": "shared/src/commonMain/kotlin/trip/Clamp.kt", "find": "return hi", "replace": "return lo", "test": ":shared:jvmTest::trip.ClampTest.inside"},
 {"label": "lo-killed", "file": "shared/src/commonMain/kotlin/trip/Clamp.kt", "find": "return lo", "replace": "return hi", "test": ":shared:jvmTest::trip.ClampTest.below"},
 {"label": "nocompile", "file": "shared/src/commonMain/kotlin/trip/Clamp.kt", "find": "return v", "replace": "return v +", "test": ":shared:jvmTest::trip.ClampTest.inside"}
]
EOF
measure mutate 3600 "scripts/mutate.sh --manifest manifest.json --out evidence/mutate --runner mutation-runner.sh" \
    bash -c '"$1" --manifest "$2" --out "$3" --runner "$4" > "$5" 2> "$6"' mutate \
    "$top/scripts/mutate.sh" "$work/manifest.json" "$ev/mutate" "$runner" "$ev/mutate.out" "$ev/mutate.err"
rc=$?
cat "$ev/mutate.out"
check "mutate: exit 1, one survivor" 1 "$rc"
check "mutate: verdicts" "survived hi-survives
killed lo-killed
did-not-compile nocompile" "$(awk 'NR >= 2 && NR <= 4 { print $1, $2 }' "$ev/mutate.out")"
check "mutate: tracked files unchanged" "" "$(git -C "$app" status --porcelain --untracked-files=no)"

cat > "$work/manifest-missing.json" <<'EOF'
[
 {"label": "missing", "file": "shared/src/commonMain/kotlin/trip/Clamp.kt", "find": "return hi", "replace": "return lo", "test": ":shared:jvmTest::trip.ClampTest.nothing"}
]
EOF
measure mutate-missing 1800 "scripts/mutate.sh --manifest manifest-missing.json --out evidence/mutate-missing --runner mutation-runner.sh" \
    bash -c '"$1" --manifest "$2" --out "$3" --runner "$4" > "$5" 2> "$6"' mutate \
    "$top/scripts/mutate.sh" "$work/manifest-missing.json" "$ev/mutate-missing" "$runner" "$ev/mutate-missing.out" "$ev/mutate-missing.err"
rc=$?
check "mutate, missing id: exit 2, refused at the baseline" 2 "$rc"
check "mutate, missing id: the baseline names it" ":shared:jvmTest::trip.ClampTest.nothing: no test ran" "$(grep -o ':shared:jvmTest::trip.ClampTest.nothing: no test ran' "$ev/mutate-missing.err")"
check "mutate, missing id: the runner wrote no entry" absent "$(entry "$(ls "$ev"/mutate-missing/baseline-*.json 2>/dev/null | head -n 1)" ":shared:jvmTest::trip.ClampTest.nothing")"

# ── 4. The --tests filter on the iOS simulator task ───────────────────────

say "4. --tests filter on :shared:iosSimulatorArm64Test (must try, not counted)"
measure runner-ios 1800 "mutation-runner.sh --out runner-ios.json --log runner-ios.runner.log -- :shared:iosSimulatorArm64Test::trip.ClampTest.inside" \
    "$runner" --out "$ev/runner-ios.json" --log "$ev/runner-ios.runner.log" -- ":shared:iosSimulatorArm64Test::trip.ClampTest.inside"
rc=$?
keep_results runner-ios shared/build/test-results/iosSimulatorArm64Test
ios_entry=$(entry "$ev/runner-ios.json" ":shared:iosSimulatorArm64Test::trip.ClampTest.inside")
note "iOS runner: exit $rc, entry $ios_entry, expected passed: $([ "$rc" -eq 0 ] && [ "$ios_entry" = passed ] && echo met || echo NOT met)"
note "iOS cases that ran with --tests trip.ClampTest.inside: $(results "$app/shared/build/test-results/iosSimulatorArm64Test" names)"

# ── 5. Serving the web app ────────────────────────────────────────────────

say "5. serving the web app"
port=8781
while :; do
    if [ -z "$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null)" ]; then
        bash "$claim" --device "web-$port" --worktree "$app" > "$ev/claim.log" 2>&1
        rc=$?
        [ "$rc" -eq 0 ] && break
        [ "$rc" -eq 5 ] || break
    fi
    port=$((port + 1))
    [ "$port" -lt 8800 ] || { rc=1; break; }
done
check "claim web-$port: exit 0" 0 "$rc"
[ "$rc" -eq 0 ] || port=""
mkdir -p "$app/composeApp/webpack.config.d"
printf 'config.devServer = config.devServer || {};\nconfig.devServer.port = %s;\nconfig.devServer.host = "localhost";\nconfig.devServer.open = false;\n' "${port:-8781}" > "$app/composeApp/webpack.config.d/serve.js"
cp "$app/composeApp/webpack.config.d/serve.js" "$ev/webpack-serve.js"

shown="$gradle_command :composeApp:wasmJsBrowserProductionRun --console=plain"
step "web-serve: $shown (detached)"
t0=$(date +%s)
(cd "$app" && exec bash -c "$gradle_command"' "$@"' gradle-command :composeApp:wasmJsBrowserProductionRun --console=plain) > "$ev/web-serve.log" 2>&1 < /dev/null &
server_pid=$!
echo "$server_pid" > "$ev/web-serve.pid"
served=""
compiled=""
while [ $(($(date +%s) - t0)) -lt 1200 ]; do
    [ -z "$served" ] && grep -qF "Loopback: http://localhost:$port/" "$ev/web-serve.log" && served=$(($(date +%s) - t0))
    [ -n "$served" ] && grep -qE '^webpack [0-9.]+ compiled' "$ev/web-serve.log" && compiled=$(($(date +%s) - t0)) && break
    ps -p "$server_pid" > /dev/null 2>&1 || break
    sleep 1
done
printf 'served at line after %s s, webpack compiled after %s s, client pid %s, port %s\n' "${served:-never}" "${compiled:-never}" "$server_pid" "$port" > "$ev/web-serve.rc"
printf '%s\t%s\t%s\t%s\t%s\n' web-serve "${served:-never}" "${compiled:-never}" "$ev/web-serve.log" "$shown" >> "$ev/summary.tsv"
step "web-serve: $(cat "$ev/web-serve.rc")"
check "web serve: the served-at line" yes "$([ -n "$served" ] && echo yes || echo no)"
check "web serve: webpack compiled" yes "$([ -n "$compiled" ] && echo yes || echo no)"
check "web serve: HTTP 200" 200 "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$port/")"
listeners=$(lsof -nP -t -iTCP:"$port" -sTCP:LISTEN 2>/dev/null)
for pid in $listeners; do
    printf '%s %s, parent %s, matched by pgrep -x webpack: %s\n' "$pid" "$(ps -o comm= -p "$pid")" "$(ps -o ppid= -p "$pid" | tr -d ' ')" \
        "$(pgrep -x webpack | grep -qx "$pid" && echo yes || echo no)" >> "$ev/web-serve-processes.log"
done
check "web serve: the listener runs as webpack" yes "$(for pid in $listeners; do pgrep -x webpack | grep -qx "$pid" && echo yes; done | head -n 1)"

# ── 6. The web screenshot ─────────────────────────────────────────────────

say "6. web screenshot"
method=""
for variant in headless swiftshader; do
    profile="$work/chrome-profile-$variant"
    mkdir -p "$profile"
    profiles+=("$profile")
    flags="--headless"
    [ "$variant" = swiftshader ] && flags="--headless --enable-unsafe-swiftshader"
    capture="'$chrome' $flags --user-data-dir=$profile --virtual-time-budget=5000 --screenshot={out} --window-size=600,800 http://localhost:$port/ & p=\$!; i=0; while [ ! -s {out} ] && [ \$i -lt 30 ]; do sleep 1; i=\$((i+1)); done; sleep 1; kill \$p; [ -s {out} ]"
    measure "settle-$variant" 600 "settle-screenshot.swift --capture \"$capture\" --out screen-web-$variant.png" \
        "$settle" --capture "$capture" --out "$ev/screen-web-$variant.png"
    rc=$?
    frame=$( [ -s "$ev/screen-web-$variant.png" ] && frame_check "$ev/screen-web-$variant.png" || echo "no: no frame")
    printf '%s\n' "$frame" > "$ev/frame-$variant.txt"
    step "frame $variant: settle exit $rc, $frame"
    stop_chrome
    if [ "$rc" -eq 0 ] && [ "${frame%%:*}" = yes ]; then
        method=$variant
        cp "$ev/screen-web-$variant.png" "$ev/screen-web.png"
        break
    fi
done
printf '%s\n' "${method:-none; the visible Chrome window fallback is not scripted}" > "$ev/web-capture-method.txt"
check "web screenshot: settled frame shows the Sample screen" yes "$([ -n "$method" ] && echo yes || echo no)"
note "web capture method: ${method:-none}"

stop_server
check "web serve: client stopped by its process id" no "$(ps -p "$(cat "$ev/web-serve.pid")" > /dev/null 2>&1 && echo yes || echo no)"
check "web serve: port $port free after the stop" "" "$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null)"
leftover=""
for profile in ${profiles[@]+"${profiles[@]}"}; do
    leftover="$leftover$(pgrep -f -- "--user-data-dir=$profile")"
done
check "Chrome: no process left with a check profile" "" "$leftover"
bash "$claim" --device "web-$port" --worktree "$app" --release > "$ev/release.log" 2>&1
check "release web-$port: exit 0" 0 $?
port=""

printf '\n'
column -t -s "$(printf '\t')" "$ev/summary.tsv" 2>/dev/null || cat "$ev/summary.tsv"
finish
