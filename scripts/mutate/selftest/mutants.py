import json
import os
import shutil
import sys


def die(msg):
    print(f"mutants: {msg}", file=sys.stderr)
    sys.exit(2)


def load(data):
    try:
        with open(data) as f:
            return json.load(f)
    except FileNotFoundError:
        die(f"cannot read {data}: no such file")
    except OSError as e:
        die(f"cannot read {data}: {e.strerror}")
    except json.JSONDecodeError as e:
        die(f"cannot read {data}: invalid JSON ({e.msg})")


def copy_files(source, dest, files):
    for f in files.split():
        os.makedirs(os.path.dirname(os.path.join(dest, f)), exist_ok=True)
        shutil.copy2(os.path.join(source, f), os.path.join(dest, f))


def build(data, index, source, dest, files):
    m = load(data)[int(index)]
    if not m.get("replacements"):
        print(f"{m['name']}: replacements is empty or missing", file=sys.stderr)
        return 1
    copy_files(source, dest, files)
    for r in m["replacements"]:
        path = os.path.join(dest, r["file"])
        with open(path) as f:
            text = f.read()
        if text.count(r["find"]) != 1:
            print(f"{m['name']}: the text to replace occurs {text.count(r['find'])} times in {r['file']}", file=sys.stderr)
            return 1
        with open(path, "w") as f:
            f.write(text.replace(r["find"], r["replace"]))
    print(f"{m['name']}\t{m['row']}")
    return 0


if __name__ == "__main__":
    if sys.argv[1] == "count":
        print(len(load(sys.argv[2])))
        sys.exit(0)
    if sys.argv[1] == "baseline":
        copy_files(*sys.argv[2:])
        sys.exit(0)
    sys.exit(build(*sys.argv[2:]))
