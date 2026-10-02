import json
import os
import subprocess

URL_PREFIX = "test://com.apple.xcode/"


# ── Verdicts ──────────────────────────────────────────────────────────────

def tool_json(tool, bundle, *what):
    cmd = tool.split() + ["get", *what, "--path", bundle]
    p = subprocess.run(cmd, capture_output=True)
    if p.returncode != 0:
        return None, f"xcresulttool get {' '.join(what)} exited {p.returncode}"
    try:
        return json.loads(p.stdout), None
    except ValueError:
        return None, f"xcresulttool get {' '.join(what)} printed invalid JSON"


def is_count(v):
    return type(v) is int and v >= 0


def verdict(exit_code, bundle, tool):
    if not os.path.isdir(bundle):
        return "error", f"no result bundle, exit {exit_code}"
    build, err = tool_json(tool, bundle, "build-results")
    if err:
        return "error", err
    status, errors = build.get("status"), build.get("errorCount")
    if exit_code == 65 and status == "failed" and is_count(errors) and errors >= 1:
        return "did-not-compile", f"{errors} build errors"
    summary, err = tool_json(tool, bundle, "test-results", "summary")
    if err:
        return "error", err
    return test_verdict(exit_code, status, errors, summary)


def test_verdict(exit_code, status, errors, s):
    built = status == "succeeded" and errors == 0
    total, failed, passed = s.get("totalTestCount"), s.get("failedTests"), s.get("passedTests")
    if exit_code == 65 and built and is_count(total) and total >= 1 and is_count(failed) and failed >= 1:
        return "killed", f"{failed} of {total} failed"
    if exit_code == 0 and built and is_count(passed) and passed >= 1 and is_count(failed) and failed == 0:
        return "survived", f"{passed} passed"
    return "error", f"exit {exit_code}, build {status}/{errors}, tests total {total} failed {failed} passed {passed}"


def names_of(node, below):
    url = node.get("nodeIdentifierURL", "")
    if url.startswith(URL_PREFIX):
        parts = url[len(URL_PREFIX):].split("/", 1)
        if len(parts) == 2:
            below.setdefault(parts[1], []).append(node)
    for child in node.get("children", []):
        names_of(child, below)


def cases_under(node):
    here = [node] if node.get("nodeType") == "Test Case" else []
    return here + [c for child in node.get("children", []) for c in cases_under(child)]


def baseline(exit_code, bundle, names, tool):
    problems = [] if exit_code == 0 else [f"xcodebuild exited {exit_code}"]
    build, err = tool_json(tool, bundle, "build-results")
    if err or build.get("status") != "succeeded" or build.get("errorCount") != 0:
        problems.append(err or f"the build did not succeed: {build.get('status')}, {build.get('errorCount')} errors")
    tree, err = tool_json(tool, bundle, "test-results", "tests")
    if err:
        return problems + [err]
    found = {}
    for node in tree.get("testNodes", []):
        names_of(node, found)
    return problems + [p for p in (name_problem(n, found) for n in names) if p]


def name_problem(name, found):
    cases = [c for node in found.get(name, []) for c in cases_under(node)]
    results = [c.get("result") for c in cases]
    if not cases:
        return f"{name}: no test ran"
    if "Failed" in results:
        return f"{name}: failed on the unmodified tree"
    if "Passed" not in results:
        return f"{name}: no test passed ({', '.join(sorted(set(map(str, results))))})"
    return None
