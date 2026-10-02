#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
bash "$here/../scripts/mutate-selftest.sh"
