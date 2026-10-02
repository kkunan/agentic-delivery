import json
import os
import sys

FIXTURE = {
    "pass": "pass",
    "killed": "killed",
    "skipped": "skipped",
    "norun": "missing",
    "nocompile": "nocompile",
    "nocompile-stale": "nocompile",
    "bad-json": "invalid",
    "bad-shape": "shape",
}
OTHER = {"id": "suite/other_test/fails", "result": "failed"}


def load(fixtures, name):
    with open(os.path.join(fixtures, name + ".json")) as f:
        return f.read()


def entries(template, ids):
    return [dict(template, id=i) for i in ids]


def contract(fixtures, outcome, ids):
    data = json.loads(load(fixtures, FIXTURE[outcome]))
    if outcome == "nocompile-stale":
        data["tests"] = entries(json.loads(load(fixtures, "killed"))["tests"][0], ids)
    elif data["tests"]:
        data["tests"] = entries(data["tests"][0], ids)
    return data


def main(outcome, fixtures, out, other_fails, *ids):
    if outcome == "bad-json":
        text = load(fixtures, "invalid")
    else:
        data = contract(fixtures, outcome, ids)
        if other_fails == "1":
            data["tests"].append(OTHER)
        text = json.dumps(data, indent=2) + "\n"
    with open(out, "w") as f:
        f.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
