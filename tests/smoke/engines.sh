#!/usr/bin/env bash
# L1 ENGINE SMOKE — drive the bin/plx-*-{ro,rw} tools on a throwaway calc fixture
# with REAL (tiny) model calls. Proves the bottom layer: the tools actually run the
# CLIs, -ro stays read-only, -rw edits land inside the repo and are correct.
# Spends a little; gated on `plx-preflight --require-<engine>` (auth -> skip, not fail).
#
#   engines.sh [--with-grok]
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-smoke.sh"

WITH_GROK="${PLX_SMOKE_WITH_GROK:-0}"
[ "${1:-}" = "--with-grok" ] && WITH_GROK=1
RUNDIR="$(smoke_run_dir)"; mkdir -p "$RUNDIR/engines"
echo "L1 engine smoke — run dir: $RUNDIR"

# READ-ONLY: a trivial question; assert exit 0, non-empty answer, repo untouched.
engine_ro() {
  local eng="$1" tool="plx-${1}-ro" repo q out log rc dirty pass
  _head "$tool — read-only holds"
  repo="$(make_tmp_repo)"
  q="$(mktemp)"; printf 'In one sentence, what does the average() function in calc.py do? Do not modify any files.\n' > "$q"
  out="$RUNDIR/engines/$tool.out"; log="$RUNDIR/engines/$tool.log"
  "$PLX_ROOT/bin/$tool" --repo "$repo" --prompt-file "$q" --out "$out" --log "$log"; rc=$?
  echo "$rc" > "$RUNDIR/engines/$tool.rc"
  dirty="$(git -C "$repo" status --porcelain 2>/dev/null)"
  pass=1
  if [ "$rc" -eq 0 ]; then _pass "$tool exit 0"; else _fail "$tool exit $rc (see $log)"; pass=0; fi
  if [ -s "$out" ]; then _pass "$tool produced an answer"; else _fail "$tool empty output"; pass=0; fi
  if [ -z "$dirty" ]; then _pass "$tool left the repo unchanged"; else _fail "$tool MODIFIED the repo (read-only breach)"; pass=0; fi
  smoke_summary_row "$RUNDIR" L1 "$tool" "$([ "$pass" -eq 1 ] && echo PASS || echo FAIL)" "read-only"
  rm -rf "$repo" "$q"
}

# SCOPED WRITE: a tiny fix; assert exit 0, repo edited, and the edit is correct.
engine_rw() {
  local eng="$1" tool="plx-${1}-rw" repo p out log rc pass
  _head "$tool — scoped write edits the repo"
  repo="$(make_tmp_repo)"
  p="$(mktemp)"; printf 'Add an empty-list guard to average() in calc.py so average([]) returns 0.0 instead of raising ZeroDivisionError. Edit calc.py only; keep it minimal.\n' > "$p"
  out="$RUNDIR/engines/$tool.out"; log="$RUNDIR/engines/$tool.log"
  "$PLX_ROOT/bin/$tool" --repo "$repo" --prompt-file "$p" --out "$out" --log "$log"; rc=$?
  echo "$rc" > "$RUNDIR/engines/$tool.rc"
  git -C "$repo" diff > "$RUNDIR/engines/$tool.diff" 2>/dev/null
  pass=1
  if [ "$rc" -eq 0 ]; then _pass "$tool exit 0"; else _fail "$tool exit $rc (see $log)"; pass=0; fi
  if [ -s "$RUNDIR/engines/$tool.diff" ]; then _pass "$tool edited the repo"; else _fail "$tool made no edits"; pass=0; fi
  if ( cd "$repo" && python3 -c "from calc import average; assert average([])==0.0 and average([1,2,3])==2" ) >/dev/null 2>&1; then
    _pass "$tool edit is correct (average([]) == 0.0)"
  else _fail "$tool edit failed the functional check"; pass=0; fi
  smoke_summary_row "$RUNDIR" L1 "$tool" "$([ "$pass" -eq 1 ] && echo PASS || echo FAIL)" "scoped-write"
  rm -rf "$repo" "$p"
}

run_engine() {
  if preflight_ok "$1"; then engine_ro "$1"; engine_rw "$1"
  else _head "plx-$1-{ro,rw}"; _skip "$1 not installed/authed — L1 $1 skipped (run \`$1 login\`?)"
       smoke_summary_row "$RUNDIR" L1 "plx-$1-{ro,rw}" SKIP "no auth"; fi
}

run_engine codex
if [ "$WITH_GROK" -eq 1 ]; then run_engine grok
else _head "plx-grok-{ro,rw}"; _skip "grok L1 skipped (pass --with-grok to include it)"; fi

summary
