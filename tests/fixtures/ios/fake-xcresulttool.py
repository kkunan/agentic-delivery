#!/usr/bin/env python3
import copy
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RESULT = {"KILL": "Failed", "EXIT0_FAILED": "Failed", "SKIP": "Skipped", "EXPECTED": "Expected Failure"}
FAILED_BUILD = ("NOCOMPILE", "NOCOMPILE_EXIT0")


def load(name):
    with open(os.path.join(HERE, name)) as f:
        return json.load(f)


def build_results(outcome):
    data = load("build-failed.json" if outcome in FAILED_BUILD + ("BUILD_ODD",) else "build-succeeded.json")
    if outcome == "BUILD_ODD":
        data["errorCount"] = 0
        data["errors"] = []
    return data


def node(template, path, result, children=None):
    n = copy.deepcopy(template)
    n["nodeIdentifierURL"] = "test://com.apple.xcode/App/" + path
    n["name"] = path.rsplit("/", 1)[-1] + ("()" if children is None else "")
    n["result"] = result
    if "nodeIdentifier" in n:
        n["nodeIdentifier"] = path.split("/", 1)[1] + "()"
    if children is not None:
        n["children"] = children
    return n


def classes(names):
    found = {}
    for name in names:
        parts = name.split("/")
        methods = found.setdefault("/".join(parts[:2]), [])
        wanted = [parts[2]] if len(parts) == 3 else ["testOne", "testTwo"]
        methods += [m for m in wanted if m not in methods]
    return found


def tests(outcome, names):
    if not names or outcome in FAILED_BUILD:
        return load("tests-none.json")
    data = load("tests-failed.json" if RESULT.get(outcome) == "Failed" else "tests-passed.json")
    plan = data["testNodes"][0]
    target = plan["children"][0]
    suite = target["children"][0]
    case = suite["children"][0]
    result = RESULT.get(outcome, "Passed")
    target["children"] = [
        node(suite, cls, result, [node(case, cls + "/" + m, result) for m in methods])
        for cls, methods in classes(names).items()
    ]
    return data


def main(args):
    if len(args) < 3 or args[0] != "get" or args[-2] != "--path":
        return 64
    what, bundle = args[1:-2], args[-1]
    try:
        with open(os.path.join(bundle, "fake-outcome")) as f:
            outcome = f.read().strip()
        with open(os.path.join(bundle, "fake-names")) as f:
            names = [line.strip() for line in f if line.strip()]
    except OSError:
        print("Error: File or directory doesn't exist at path: %s." % bundle)
        return 64
    if outcome == "TOOL_FAIL":
        return 1
    if outcome == "BAD_JSON":
        print("{not json")
        return 0
    if what == ["build-results"]:
        print(json.dumps(build_results(outcome), indent=2))
    elif what == ["test-results", "tests"]:
        print(json.dumps(tests(outcome, names), indent=2))
    else:
        return 64
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
