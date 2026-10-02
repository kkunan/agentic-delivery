import copy
import json
import os
import sys

TARGETS = ("AppTests", "AppUITests")
BUILD = {"nocompile": "nocompile", "norun": "missing", "killed": "killed"}
SUMMARY = {"nocompile": "nocompile", "norun": "missing", "killed": "killed", "skipped": "skipped"}
RESULT = {"killed": "Failed", "skipped": "Skipped"}


def load(fixtures, name):
    with open(os.path.join(fixtures, name)) as f:
        return f.read()


def summary(fixtures, outcome):
    text = load(fixtures, SUMMARY.get(outcome, "pass") + ".test-results.json")
    if outcome != "no-field":
        return text
    data = json.loads(text)
    del data["totalTestCount"], data["passedTests"]
    return json.dumps(data, indent=2)


def node(template, path, result, children=None):
    n = copy.deepcopy(template)
    n["nodeIdentifierURL"] = "test://com.apple.xcode/App/" + path
    n["name"] = path.rsplit("/", 1)[-1]
    n["result"] = result
    if "nodeIdentifier" in n:
        n["nodeIdentifier"] = path.split("/", 1)[1] + "()"
    if children is not None:
        n["children"] = children
    return n


def tree(fixtures, outcome, names):
    if outcome == "norun":
        return load(fixtures, "missing.tests.json")
    if outcome == "nocompile":
        return load(fixtures, "nocompile.tests.json")
    data = json.loads(load(fixtures, ("killed" if outcome == "killed" else "pass") + ".tests.json"))
    plan = data["testNodes"][0]
    bundle = plan["children"][0]
    suite = bundle["children"][0]
    case = suite["children"][0]
    result = RESULT.get(outcome, "Passed")
    suites = []
    for name in names:
        parts = name.split("/")
        if parts[0] not in TARGETS or len(parts) not in (2, 3):
            continue
        tests = [node(case, name, result)] if len(parts) == 3 else [node(case, name + "/testSelftest", result)]
        suites.append(node(suite, "/".join(parts[:2]), result, tests))
    bundle["children"] = suites
    plan["children"] = [bundle] if suites else []
    return json.dumps(data, indent=2)


def main(what, outcome, names_file, fixtures):
    if outcome == "tool-fail":
        return 64
    if outcome == "bad-json":
        print("{not json")
        return 0
    with open(names_file) as f:
        names = [line.strip() for line in f if line.strip()]
    if what == "build-results":
        print(load(fixtures, BUILD.get(outcome, "pass") + ".build-results.json"))
    elif what == "test-results-summary":
        print(summary(fixtures, outcome))
    elif what == "test-results-tests":
        print(tree(fixtures, outcome, names))
    else:
        return 64
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
