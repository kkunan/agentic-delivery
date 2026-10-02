#!/bin/bash
root=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd -P) || exit 0
docs_dir=$(bash "$root/scripts/project-config.sh" docs_dir "" 2>/dev/null) || docs_dir=""
top=$(git rev-parse --show-toplevel 2>/dev/null) || top=""
python3 -c '
import json
import os
import sys

docs_dir, top = sys.argv[1:3]
try:
    data = json.load(sys.stdin)
    path = data["tool_input"]["file_path"]
    if not isinstance(path, str) or not path:
        sys.exit(0)
except Exception:
    sys.exit(0)

path = os.path.abspath(path)
inside = "/docs/superpowers/retros/" in path
if not inside and docs_dir:
    if docs_dir.startswith("~/"):
        docs_dir = os.path.expanduser(docs_dir)
    if not os.path.isabs(docs_dir):
        docs_dir = os.path.join(top, docs_dir) if top else ""
    if docs_dir:
        retros = os.path.realpath(os.path.join(docs_dir, "retros"))
        inside = os.path.realpath(path).startswith(retros + os.sep)
if not inside:
    sys.exit(0)

text = (
    "You are writing a retro. Do not edit any plugin file. "
    "Propose each rule change as a pull request to the plugin repository, "
    "as an action item that names the plugin file where the change belongs."
)
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": text}}))
' "$docs_dir" "$top" 2>/dev/null
exit 0
