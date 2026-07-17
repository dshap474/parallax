#!/usr/bin/env bash
# L2 SKILL SMOKE — run each /plx:* skill END-TO-END via headless `claude --plugin-dir`
# against a throwaway fixture, then assert on the resulting diff / files / transcript.
# This loads THIS working copy of the plugin (not the installed cache) and captures the
# full stream-json transcript of every engine lane — the audit artifact. Spends real
# tokens. Lanes run as background Bash inside the headless session, so the 10-min
# background wait ceiling is lifted via CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0.
#
#   skills.sh [--skill <name>] [--with-grok] [--dry-run]
#
# Each scenarios/<skill>.txt declares: NEEDS (engine auth gate), FIXTURE, TASK, and any of
# EXPECT_DIFF / EXPECT_EMPTY_DIFF / EXPECT_FILE / EXPECT_OUTPUT / EXPECT_CHECK.
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-smoke.sh"

ONLY=""; DRY=0; WITH_GROK="${PLX_SMOKE_WITH_GROK:-0}"
while [ $# -gt 0 ]; do
  case "$1" in
    --skill) ONLY="$2"; shift 2 ;;
    --with-grok) WITH_GROK=1; shift ;;
    --dry-run) DRY=1; shift ;;
    *) echo "usage: skills.sh [--skill <name>] [--with-grok] [--dry-run]" >&2; exit 2 ;;
  esac
done

if [ "$DRY" -eq 0 ] && ! command -v claude >/dev/null 2>&1; then
  _head "L2 skill smoke"; _fail "claude CLI not found — L2 needs it"; summary; exit 1
fi
RUNDIR="$(smoke_run_dir)"; mkdir -p "$RUNDIR/skills"
echo "L2 skill smoke — run dir: $RUNDIR"

# field <scenario-file> <KEY> -> value after "KEY:" (empty if absent/blank).
field() { sed -n "s/^$2:[[:space:]]*//p" "$1" | head -1; }

goal_spec_note() {
  _head "/plx:goal-spec"
  _skip "interactive (AskUserQuestion interview + approval gate) — not runnable under \`claude -p\`; see tests/smoke/README.md for the manual check"
  smoke_summary_row "$RUNDIR" L2 goal-spec SKIP "interactive — manual check"
}

run_skill() {
  local skill="$1" scn d fix task needs repo base prompt rc ok notes v
  scn="$SMOKE_DIR/scenarios/$skill.txt"
  _head "/plx:$skill"
  if [ ! -f "$scn" ]; then _fail "no scenario file: tests/smoke/scenarios/$skill.txt"; return; fi
  needs="$(field "$scn" NEEDS)"; fix="$(field "$scn" FIXTURE)"; task="$(field "$scn" TASK)"
  d="$RUNDIR/skills/$skill"; mkdir -p "$d"

  if [ "$DRY" -eq 0 ] && [ -n "$needs" ] && ! preflight_ok "$needs"; then
    _skip "needs $needs (not installed/authed) — skipped"
    smoke_summary_row "$RUNDIR" L2 "$skill" SKIP "no $needs auth"; return
  fi

  repo="$(make_tmp_repo "$(fixture_dir "$fix")")"
  base="$(git -C "$repo" rev-list --max-parents=0 HEAD 2>/dev/null)"
  if [ -n "$task" ]; then prompt="/plx:$skill $task"; else prompt="/plx:$skill"; fi
  {
    printf 'cd %s\n' "$repo"
    printf 'PATH=%s/bin:$PATH CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0 claude -p %s \\\n' "$PLUGIN_ROOT" "$(printf '%q' "$prompt")"
    printf '  --plugin-dir %s --permission-mode bypassPermissions \\\n' "$PLUGIN_ROOT"
    printf '  --output-format stream-json --verbose\n'
  } > "$d/cmd.txt"

  if [ "$DRY" -eq 1 ]; then
    _skip "dry-run — fixture at $repo, command in $d/cmd.txt"
    smoke_summary_row "$RUNDIR" L2 "$skill" DRY "fixture: $fix"
    rm -rf "$repo"; return
  fi

  ( cd "$repo" && PATH="$PLUGIN_ROOT/bin:$PATH" CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0 claude -p "$prompt" \
      --plugin-dir "$PLUGIN_ROOT" --permission-mode bypassPermissions \
      --output-format stream-json --verbose ) > "$d/transcript.jsonl" 2> "$d/stderr.log"
  rc=$?; echo "$rc" > "$d/rc"
  git -C "$repo" diff "$base" > "$d/diff.patch" 2>/dev/null
  git -C "$repo" status --short > "$d/repo-status.txt" 2>/dev/null

  ok=1; notes=""
  if [ "$rc" -eq 0 ]; then _pass "claude exit 0"; else _fail "claude exit $rc (see $d/stderr.log)"; ok=0; notes="exit$rc"; fi

  v="$(field "$scn" EXPECT_DIFF)"
  if [ -n "$v" ]; then
    if grep -Eq -- "$v" "$d/diff.patch"; then _pass "diff matches /$v/"; else _fail "diff missing /$v/"; ok=0; notes="$notes,diff"; fi
  fi
  v="$(field "$scn" EXPECT_EMPTY_DIFF)"
  if [ "$v" = "true" ]; then
    if [ -s "$d/diff.patch" ]; then _fail "expected NO edits, but the repo changed"; ok=0; notes="$notes,edited"; else _pass "read-only: repo unchanged"; fi
  fi
  v="$(field "$scn" EXPECT_FILE)"
  if [ -n "$v" ]; then
    if [ -e "$repo/$v" ]; then _pass "created $v"; else _fail "missing expected file $v"; ok=0; notes="$notes,no-$v"; fi
  fi
  v="$(field "$scn" EXPECT_OUTPUT)"
  if [ -n "$v" ]; then
    if grep -Eiq -- "$v" "$d/transcript.jsonl"; then _pass "transcript matches /$v/"; else _fail "transcript missing /$v/"; ok=0; notes="$notes,output"; fi
  fi
  v="$(field "$scn" EXPECT_CHECK)"
  if [ -n "$v" ]; then
    if ( cd "$repo" && eval "$v" ) > "$d/check.txt" 2>&1; then _pass "check passed"; else _fail "check failed: $v"; ok=0; notes="$notes,check"; fi
  fi

  smoke_summary_row "$RUNDIR" L2 "$skill" "$([ "$ok" -eq 1 ] && echo PASS || echo FAIL)" "${notes:-ok}"
  rm -rf "$repo"
}

if [ -n "$ONLY" ]; then
  if [ "$ONLY" = "goal-spec" ]; then goal_spec_note; else run_skill "$ONLY"; fi
else
  for s in plan build review dev codex agents-memory; do run_skill "$s"; done
  if [ "$WITH_GROK" -eq 1 ]; then run_skill grok; else _head "/plx:grok"; _skip "skipped (pass --with-grok)"; smoke_summary_row "$RUNDIR" L2 grok SKIP "no --with-grok"; fi
  goal_spec_note
fi

echo; echo "transcripts + diffs under: $RUNDIR/skills/"
summary
