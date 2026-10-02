import hashlib
import json
import os
import re
import subprocess

KEYS = ("label", "file", "find", "replace", "test")
LABEL = re.compile(r"[A-Za-z0-9_-][A-Za-z0-9._-]*\Z")


class Refusal(Exception):
    pass


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def count(data, needle):
    n, i = 0, data.find(needle)
    while i != -1:
        n, i = n + 1, data.find(needle, i + 1)
    return n


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], capture_output=True)


# ── The list ──────────────────────────────────────────────────────────────

def no_duplicates(pairs):
    keys = [k for k, _ in pairs]
    for k in keys:
        if keys.count(k) > 1:
            raise Refusal(f"key {k!r} occurs twice in one entry")
    return dict(pairs)


def read_list(path):
    try:
        with open(path, "rb") as f:
            raw = f.read()
        entries = json.loads(raw.decode("utf-8"), object_pairs_hook=no_duplicates)
    except Refusal:
        raise
    except Exception as e:
        raise Refusal(f"cannot read the list {path}: {e}")
    if not isinstance(entries, list) or not entries:
        raise Refusal("the list must be a JSON array with at least one entry")
    return [check_entry(i, e) for i, e in enumerate(entries)]


def check_entry(i, e):
    if not isinstance(e, dict):
        raise Refusal(f"entry {i} is not an object")
    if set(e) != set(KEYS):
        raise Refusal(f"entry {i} must have exactly the keys {', '.join(KEYS)}; it has {', '.join(sorted(e))}")
    for k in KEYS:
        if not isinstance(e[k], str):
            raise Refusal(f"entry {i}: {k} is not a string")
        try:
            e[k].encode("utf-8")
        except UnicodeEncodeError:
            raise Refusal(f"entry {i}: {k} cannot be encoded as UTF-8")
    check_fields(i, e)
    return e


def check_fields(i, e):
    if not LABEL.match(e["label"]) or len(e["label"]) > 100:
        raise Refusal(f"entry {i}: label {e['label']!r} must use letters, digits, . _ -, not start with ., and be at most 100 long")
    if not e["find"]:
        raise Refusal(f"{e['label']}: find is empty")
    if e["find"] == e["replace"]:
        raise Refusal(f"{e['label']}: replace is the same as find")
    t = e["test"]
    if "/" not in t or "(" in t or re.search(r"\s", t):
        raise Refusal(f"{e['label']}: test {t!r} must name its target, and hold no ( and no space")


def check_labels(entries):
    seen = {}
    for e in entries:
        key = e["label"].lower()
        if key in seen:
            raise Refusal(f"labels {seen[key]!r} and {e['label']!r} are the same without regard to case")
        seen[key] = e["label"]


# ── Target files ──────────────────────────────────────────────────────────

def check_target(repo, self_dir, e):
    rel = e["file"]
    if re.search(r"[\t\n]", rel):
        raise Refusal(f"{e['label']}: file name holds a tab or a newline")
    path = os.path.normpath(os.path.join(repo, rel))
    if not path.startswith(repo + os.sep):
        raise Refusal(f"{e['label']}: {rel} is outside the repository")
    if os.path.realpath(path) != path:
        raise Refusal(f"{e['label']}: {rel} is or passes through a symbolic link")
    if not os.path.isfile(path):
        raise Refusal(f"{e['label']}: {rel} is not a regular file")
    if is_runner_file(path, repo, self_dir):
        raise Refusal(f"{e['label']}: {rel} is one of the runner's own files")
    check_clean(repo, e["label"], rel)
    return path


def is_runner_file(path, repo, self_dir):
    own = [os.path.join(self_dir, "mutate.sh"), os.path.join(repo, "scripts", "mutate.sh")]
    dirs = [os.path.join(self_dir, "mutate"), os.path.join(repo, "scripts", "mutate")]
    real = os.path.realpath(path)
    if real in [os.path.realpath(p) for p in own]:
        return True
    return any(real.startswith(os.path.realpath(d) + os.sep) for d in dirs)


def check_clean(repo, label, rel):
    tracked = git(repo, "ls-files", "--error-unmatch", "--", rel)
    if tracked.returncode != 0:
        raise Refusal(f"{label}: {rel} is not tracked by git")
    status = git(repo, "status", "--porcelain", "--", rel)
    if status.returncode != 0 or status.stdout.strip():
        raise Refusal(f"{label}: {rel} has uncommitted changes, or git status failed")


def check_match(path, e):
    with open(path, "rb") as f:
        n = count(f.read(), e["find"].encode("utf-8"))
    if n != 1:
        raise Refusal(f"{e['label']}: find occurs {n} times in {e['file']}; it must occur exactly once")


def validate(manifest, repo, self_dir):
    entries = read_list(manifest)
    check_labels(entries)
    for e in entries:
        check_match(check_target(repo, self_dir, e), e)
    for e in entries:
        print("\t".join((e["label"], e["file"], e["test"])))
