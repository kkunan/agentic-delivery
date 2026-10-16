#!/bin/bash
set -u

here=$(cd "$(dirname "$0")" && pwd -P)
top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "test.sh: run it inside a worktree of the web app" >&2; exit 2; }
cd "$top" || exit 2
[ -d node_modules/next ] || { echo "test.sh: run npm ci in $top first" >&2; exit 2; }

packages='jest@29.7.0 jest-environment-jsdom@29.7.0 @testing-library/react@16.0.1 @testing-library/dom@10.4.0 @testing-library/jest-dom@6.6.3 @types/jest@29.5.14'
if [ ! -x node_modules/.bin/jest ] || [ ! -d node_modules/@testing-library/react ] || [ ! -d node_modules/jest-environment-jsdom ]; then
    npm install --no-save --no-audit --no-fund $packages >&2 || exit 2
fi
git diff --quiet -- package.json package-lock.json || { echo "test.sh: package.json or package-lock.json changed. Restore them before you commit" >&2; }

exec node_modules/.bin/jest --config "$here/jest.config.js" "$@"
