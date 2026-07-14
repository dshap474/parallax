#!/usr/bin/env bash
# L1 ENGINE SMOKE — drive bin/plx-engine on a throwaway calc fixture with REAL
# (tiny) model calls. Proves the bottom layer: the wrapper actually runs each CLI,
# --mode ro stays read-only and injects rubrics, --mode rw edits land inside the
# repo and are correct.
# Spends a little; gated on `plx-preflight --require-<engine>` (auth -> skip, not fail).
#
#   engines.sh [--with-grok]
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-smoke.sh"

WITH_GROK="${PLX_SMOKE_WITH_GROK:-0}"
[ "${1:-}" = "--with-grok" ] && WITH_GROK=1
RUNDIR="$(smoke_run_dir)"; mkdir -p "$RUNDIR/engines"
echo "L1 engine smoke — run dir: $RUNDIR"

# effort_flags <engine> — every engine accepts low effort for this tiny fixture.
effort_flags() { printf -- '--effort low'; }

# READ-ONLY + RUBRIC: review the seeded bug via --rubric reviewer-correctness.
# Assert exit 0, a finding that names the empty-list/ZeroDivisionError bug, repo untouched.
engine_ro() {
  local eng="$1" repo q out log rc dirty pass
  _head "plx-engine --engine $eng --mode ro — read-only holds, rubric injects"
  repo="$(make_tmp_repo)"
  q="$(mktemp)"
  {
    printf '## Review brief\n'
    printf -- '- Repo: %s\n' "$repo"
    printf -- '- Files touched: calc.py\n'
    printf -- '- What was implemented / what to scrutinize: the average() function in calc.py\n'
  } > "$q"
  out="$RUNDIR/engines/$eng-ro.out"; log="$RUNDIR/engines/$eng-ro.log"
  # shellcheck disable=SC2046
  "$PLX_ROOT/bin/plx-engine" --engine "$eng" --mode ro --repo "$repo" \
    --prompt-file "$q" --rubric reviewer-correctness $(effort_flags "$eng") \
    --out "$out" --log "$log"; rc=$?
  echo "$rc" > "$RUNDIR/engines/$eng-ro.rc"
  dirty="$(git -C "$repo" status --porcelain 2>/dev/null)"
  pass=1
  if [ "$rc" -eq 0 ]; then _pass "$eng ro exit 0"; else _fail "$eng ro exit $rc (see $log)"; pass=0; fi
  if [ -s "$out" ]; then _pass "$eng ro produced findings"; else _fail "$eng ro empty output"; pass=0; fi
  if grep -Eiq 'zerodivision|empty|divide by zero|len\(numbers\)' "$out"; then
    _pass "$eng ro found the seeded empty-list bug (rubric applied)"
  else _fail "$eng ro missed the seeded bug (rubric injection suspect)"; pass=0; fi
  if [ -z "$dirty" ]; then _pass "$eng ro left the repo unchanged"; else _fail "$eng ro MODIFIED the repo (read-only breach)"; pass=0; fi
  smoke_summary_row "$RUNDIR" L1 "plx-engine $eng ro" "$([ "$pass" -eq 1 ] && echo PASS || echo FAIL)" "read-only+rubric"
  rm -rf "$repo" "$q"
}

# SCOPED WRITE: a tiny fix (passthrough-style, no rubric); assert exit 0, repo edited, edit correct.
engine_rw() {
  local eng="$1" repo p out log rc pass
  _head "plx-engine --engine $eng --mode rw — scoped write edits the repo"
  repo="$(make_tmp_repo)"
  p="$(mktemp)"; printf 'Add an empty-list guard to average() in calc.py so average([]) returns 0.0 instead of raising ZeroDivisionError. Edit calc.py only; keep it minimal.\n' > "$p"
  out="$RUNDIR/engines/$eng-rw.out"; log="$RUNDIR/engines/$eng-rw.log"
  # shellcheck disable=SC2046
  "$PLX_ROOT/bin/plx-engine" --engine "$eng" --mode rw --repo "$repo" \
    --prompt-file "$p" $(effort_flags "$eng") \
    --out "$out" --log "$log"; rc=$?
  echo "$rc" > "$RUNDIR/engines/$eng-rw.rc"
  git -C "$repo" diff > "$RUNDIR/engines/$eng-rw.diff" 2>/dev/null
  pass=1
  if [ "$rc" -eq 0 ]; then _pass "$eng rw exit 0"; else _fail "$eng rw exit $rc (see $log)"; pass=0; fi
  if [ -s "$RUNDIR/engines/$eng-rw.diff" ]; then _pass "$eng rw edited the repo"; else _fail "$eng rw made no edits"; pass=0; fi
  if ( cd "$repo" && python3 -c "from calc import average; assert average([])==0.0 and average([1,2,3])==2" ) >/dev/null 2>&1; then
    _pass "$eng rw edit is correct (average([]) == 0.0)"
  else _fail "$eng rw edit failed the functional check"; pass=0; fi
  smoke_summary_row "$RUNDIR" L1 "plx-engine $eng rw" "$([ "$pass" -eq 1 ] && echo PASS || echo FAIL)" "scoped-write"
  rm -rf "$repo" "$p"
}

run_engine() {
  if preflight_ok "$1"; then engine_ro "$1"; engine_rw "$1"
  else _head "plx-engine --engine $1"; _skip "$1 not installed/authed — L1 $1 skipped"
       smoke_summary_row "$RUNDIR" L1 "plx-engine $1" SKIP "no auth"; fi
}

# Free check first: rubric plumbing answers without a model call.
_head "plx-engine --print-rubric (no model call)"
if "$PLX_ROOT/bin/plx-engine" --print-rubric engines | grep -q "Engines"; then
  _pass "--print-rubric engines resolves prompts/"
else
  _fail "--print-rubric engines failed — prompts/ resolution broken"
fi

run_engine codex
run_engine claude
if [ "$WITH_GROK" -eq 1 ]; then run_engine grok
else _head "plx-engine --engine grok"; _skip "grok L1 skipped (pass --with-grok to include it)"; fi

summary
