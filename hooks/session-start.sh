#!/bin/bash
root=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd -P) || exit 0
cfg="$root/scripts/project-config.sh"
platform=$(bash "$cfg" platform 2>/dev/null) || exit 0
[ -n "$platform" ] || exit 0
minimum=$(bash "$cfg" min_plugin_version "" 2>/dev/null) || minimum=""
python3 - "$root/.claude-plugin/plugin.json" "$platform" "$minimum" "$root" 2>/dev/null <<'PY'
import json
import re
import sys

plugin_file, platform, minimum, root = sys.argv[1:5]
if not re.fullmatch(r"[A-Za-z0-9_-]{1,40}", platform):
    sys.exit(0)

def parts(value):
    if not re.fullmatch(r"[0-9]+(\.[0-9]+)*", value):
        raise ValueError(value)
    return [int(p) for p in value.split(".")]

warning = ""
try:
    with open(plugin_file) as handle:
        version = str(json.load(handle)["version"])
    have, need = parts(version), parts(minimum)
    size = max(len(have), len(need))
    have += [0] * (size - len(have))
    need += [0] * (size - len(need))
    if have < need:
        warning = "agentic-delivery %s is older than this project needs (%s). Update the plugin. " % (version, minimum)
except Exception:
    warning = ""

pointer = (
    "Agentic delivery is on in this project. To build a feature, run /feature. "
    "Its first step loads the controller skill and the run-rules skill, "
    "then the platform-%s skill. After a compaction, load the controller skill again. "
    "In the plugin skills and commands, scripts/ means the folder %s/scripts, not a folder in the project." % (platform, root)
)
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": warning + pointer}}))
PY
exit 0
