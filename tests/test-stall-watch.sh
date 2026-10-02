#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/lib.sh"
watch="$here/../scripts/stall-watch.sh"
work=$(cd "$(mktemp -d)" && pwd -P)
git -C "$work" init -q
mkdir "$work/root"
ln -s /bin/sleep "$work/fake_tester"
"$work/fake_tester" 30 &
fake_pid=$!
cd "$work"

out=$(bash "$watch" --process fake_tester --roots "$work/root" --interval 1 --build-after 0 --polls 3 2>&1)
check "a frozen process is reported" 1 "$(printf '%s\n' "$out" | grep -c 'BUILD FROZEN')"
check "the frozen line names the process" 1 "$(printf '%s\n' "$out" | grep -c "BUILD FROZEN.*fake_tester")"
check "every heartbeat carries the disk figure" 4 "$(printf '%s\n' "$out" | grep -c 'HEARTBEAT.*disk=[0-9?]*G$')"
check "every poll prints a heartbeat" 4 "$(printf '%s\n' "$out" | grep -c 'HEARTBEAT')"

bash "$watch" --process fake_tester --roots "$work/root" --interval 1 --polls 1 >/dev/null 2>&1
check "--polls stops the loop with exit 0" 0 $?

out=$(bash "$watch" --process no_such_process_name --roots "$work/root" --interval 1 --build-after 0 --polls 3 2>&1)
check "an absent process is not reported" 0 "$(printf '%s\n' "$out" | grep -c 'BUILD FROZEN')"

bash "$watch" --roots "$work/root" --interval 1 --polls 1 >/dev/null 2>&1
check "no process and no project file refuses to start" 2 $?
msg=$(bash "$watch" --roots "$work/root" --interval 1 --polls 1 2>&1)
check "the refusal says what to set" 1 "$(printf '%s\n' "$msg" | grep -c 'test_processes')"

bash "$watch" --process fake_tester --roots /nonexistent --interval 1 --polls 1 >/dev/null 2>&1
check "a missing root refuses to start" 2 $?

mkdir "$work/.claude"
printf -- '---\ntest_processes: fake_tester,other_name\n---\n' > "$work/.claude/agentic-delivery.md"
out=$(bash "$watch" --roots "$work/root" --interval 1 --build-after 0 --polls 3 2>&1)
check "test_processes from the project file is watched" 1 "$(printf '%s\n' "$out" | grep -c 'BUILD FROZEN')"
rm "$work/.claude/agentic-delivery.md"

out=$(cd "$work" && bash "$watch" --process fake_tester --roots "$work/root" --interval 1 --polls 1 2>&1)
check "the disk figure is free space in GB" 2 "$(printf '%s\n' "$out" | grep -c 'disk=[0-9][0-9]*G$')"
check "plenty of space prints no warning" 0 "$(printf '%s\n' "$out" | grep -c 'DISK LOW')"

mkdir "$work/bin"
printf '#!/bin/bash\nprintf "Filesystem 1G-blocks Used Available Capacity Mounted\\n/dev/x 100 98 2 98%% /\\n"\n' > "$work/bin/df"
chmod +x "$work/bin/df"
out=$(PATH="$work/bin:$PATH" bash "$watch" --process fake_tester --roots "$work/root" --interval 1 --polls 1 2>&1)
check "low space prints the warning" 2 "$(printf '%s\n' "$out" | grep -c 'DISK LOW 2G$')"
check "low space still prints the heartbeat figure" 2 "$(printf '%s\n' "$out" | grep -c 'HEARTBEAT.*disk=2G$')"
rm "$work/bin/df"
rmdir "$work/bin"

mkdir "$work/main" "$work/wt-a" "$work/wt-b"
git -C "$work/main" init -q
git -C "$work/main" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
git -C "$work/main" worktree add -q "$work/wt-a" -b wt-a
git -C "$work/main" worktree add -q "$work/wt-b" -b wt-b
out=$(cd "$work/main" && bash "$watch" --process fake_tester --interval 1 --polls 1 --exclude "$work/wt-b" 2>&1)
check "--exclude removes a default root" 1 "$(printf '%s\n' "$out" | grep -c 'watching 1 worktree')"
out=$(cd "$work/main" && bash "$watch" --process fake_tester --interval 1 --polls 1 2>&1)
check "default roots skip the main worktree" 1 "$(printf '%s\n' "$out" | grep -c 'watching 2 worktree')"
rm -rf "$work/main" "$work/wt-a" "$work/wt-b"

kill "$fake_pid" 2>/dev/null
wait "$fake_pid" 2>/dev/null
rmdir "$work/.claude" "$work/root"
rm -rf "$work/.git"
rm "$work/fake_tester"
rmdir "$work"
finish
