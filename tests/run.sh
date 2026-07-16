#!/usr/bin/env bash
# Run static integrity plus the packaged runtime smoke against both host plugins.
# Usage: bash tests/run.sh [--with-engines]
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

rc=0
bash "$HERE/check-plugin.sh" || rc=1
PLX_PACKAGE=claude bash "$HERE/smoke-scripts.sh" "$@" || rc=1
PLX_PACKAGE=codex bash "$HERE/smoke-scripts.sh" "$@" || rc=1

echo
if [ "$rc" -eq 0 ]; then
  echo "ALL GREEN"
else
  echo "FAILURES — see above"
fi
exit "$rc"
