import json

RESULTS = ("passed", "failed", "skipped")


# ── The result file ───────────────────────────────────────────────────────

def read_result(path, exit_code):
    try:
        with open(path, "rb") as f:
            raw = f.read()
    except FileNotFoundError:
        return None, f"no result file, runner exit {exit_code}"
    except OSError as e:
        return None, f"cannot read the result file ({e.strerror}), runner exit {exit_code}"
    try:
        data = json.loads(raw.decode("utf-8"))
    except ValueError:
        return None, f"the result file is not valid JSON, runner exit {exit_code}"
    problem = shape_problem(data)
    if problem:
        return None, f"the result file has the wrong shape: {problem}"
    return data, None


def shape_problem(data):
    if not isinstance(data, dict):
        return "the top level is not an object"
    if type(data.get("compiled")) is not bool:
        return "compiled is not true or false"
    if not isinstance(data.get("tests"), list):
        return "tests is not an array"
    for i, t in enumerate(data["tests"]):
        if not isinstance(t, dict) or not isinstance(t.get("id"), str) or t.get("result") not in RESULTS:
            return f"tests entry {i} needs a string id and a result of passed, failed or skipped"
    return None


def results_of(data, name):
    return [t["result"] for t in data["tests"] if t["id"] == name]


# ── Verdicts ──────────────────────────────────────────────────────────────

def verdict(exit_code, path, names):
    data, err = read_result(path, exit_code)
    if err:
        return "error", err
    if not data["compiled"]:
        return "did-not-compile", "the runner says the code did not compile"
    found = {n: results_of(data, n) for n in names}
    failed = [n for n in names if "failed" in found[n]]
    if failed:
        return "killed", f"{', '.join(failed)} failed"
    if names and all(found[n] and set(found[n]) == {"passed"} for n in names):
        return "survived", f"{', '.join(names)} passed"
    return "error", "; ".join(error_reason(n, found[n]) for n in names if set(found[n]) != {"passed"})


def error_reason(name, results):
    if not results:
        return f"{name} is absent from tests"
    return f"{name}: {', '.join(results)}"


# ── The baseline ──────────────────────────────────────────────────────────

def baseline(exit_code, path, names):
    data, err = read_result(path, exit_code)
    if err:
        return [err]
    if data["compiled"] is False:
        return ["the runner says the code did not compile on the unmodified tree"]
    return [p for p in (baseline_problem(n, results_of(data, n)) for n in names) if p]


def baseline_problem(name, results):
    if not results:
        return f"{name}: no test ran"
    if "failed" in results:
        return f"{name}: failed on the unmodified tree"
    if "passed" not in results:
        return f"{name}: no test passed ({', '.join(sorted(set(results)))})"
    return None
