#!/usr/bin/env bash
# Run the deterministic Parallax test suite: static integrity + script smoke.
# Pass --with-engines to also probe codex/grok in the script smoke phase.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

rc=0
bash "$HERE/check-plugin.sh" || rc=1
bash "$HERE/smoke-scripts.sh" "$@" || rc=1

echo
if [ "$rc" -eq 0 ]; then
  echo "ALL GREEN"
else
  echo "FAILURES — see above"
fi
exit "$rc"
