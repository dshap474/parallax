#!/usr/bin/env bash
# Run model-free integrity, packaged runtime, and vendored client tests.
# Usage: bash tests/run.sh [--with-engines]
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# --------------------------------------------------------------------------- #
# Suite entry point
# --------------------------------------------------------------------------- #

rc=0
bash "$HERE/check-plugin.sh" || rc=1
PLX_PACKAGE=claude bash "$HERE/smoke-scripts.sh" "$@" || rc=1
PLX_PACKAGE=codex bash "$HERE/smoke-scripts.sh" "$@" || rc=1

bash "$HERE/client.sh" || rc=1

echo
if [ "$rc" -eq 0 ]; then
  echo "ALL GREEN"
else
  echo "FAILURES — see above"
fi
exit "$rc"
