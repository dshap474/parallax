#!/usr/bin/env bash
# Parallax BEHAVIORAL smoke suite — runs skills/engines for REAL against throwaway
# fixtures and captures full logs, so you can audit the live system end to end.
# (tests/run.sh is the static, model-free suite; this one spends tokens.)
#
# Usage:
#   run-smoke.sh                 L1 engine smoke only (cheap, a few tiny calls)
#   run-smoke.sh --skills        L1 + L2 — every skill end to end (full audit, costs tokens)
#   run-smoke.sh --skill dev     one skill end to end (L2)
#   run-smoke.sh --engines       L1 only (explicit)
#   run-smoke.sh --with-grok ... include grok lanes (off by default)
#   run-smoke.sh --dry-run ...   prepare fixtures + print commands, run nothing
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

usage() { sed -n '6,12p' "$0" | sed 's/^# \{0,1\}//'; }

MODE="engines"; ONLY=""; DRY=0; WITH_GROK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --skills) MODE="skills"; shift ;;
    --engines) MODE="engines"; shift ;;
    --skill) MODE="one"; ONLY="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --with-grok) WITH_GROK=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown flag: $1 (try --help)" >&2; exit 2 ;;
  esac
done

PLX_SMOKE_RUNDIR="$HERE/logs/$(date +%Y-%m-%dT%H-%M-%S)"
export PLX_SMOKE_RUNDIR
export PLX_SMOKE_WITH_GROK="$WITH_GROK"
mkdir -p "$PLX_SMOKE_RUNDIR"
echo "Parallax smoke — run dir: $PLX_SMOKE_RUNDIR"
[ "$DRY" -eq 1 ] && echo "(dry-run: nothing actually executes)"

g=""; [ "$WITH_GROK" -eq 1 ] && g="--with-grok"
rc=0
case "$MODE" in
  engines)
    if [ "$DRY" -eq 1 ]; then echo "(dry-run) would run: engines.sh $g"; else bash "$HERE/engines.sh" $g || rc=1; fi ;;
  skills)
    if [ "$DRY" -eq 1 ]; then echo "(dry-run) skipping engines.sh"; else bash "$HERE/engines.sh" $g || rc=1; fi
    d=""; [ "$DRY" -eq 1 ] && d="--dry-run"
    bash "$HERE/skills.sh" $g $d || rc=1 ;;
  one)
    d=""; [ "$DRY" -eq 1 ] && d="--dry-run"
    bash "$HERE/skills.sh" --skill "$ONLY" $g $d || rc=1 ;;
esac

echo
if [ -f "$PLX_SMOKE_RUNDIR/summary.md" ]; then echo "== summary =="; cat "$PLX_SMOKE_RUNDIR/summary.md"; fi
echo
echo "full logs: $PLX_SMOKE_RUNDIR"
exit "$rc"
