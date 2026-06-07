#!/usr/bin/env bash
# Smoke-test the deterministic shell scripts against an ISOLATED tmp repo.
# By default no engine (codex/grok) calls are made — preflight is run without
# --require-* so it stays model-free. Pass --with-engines to also probe codex/grok.
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

WITH_ENGINES=0
[ "${1:-}" = "--with-engines" ] && WITH_ENGINES=1

REPO="$(make_tmp_repo)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/plx-smoke.XXXXXX")"
trap 'rm -rf "$REPO" "$WORK"' EXIT
echo "tmp target repo: $REPO"

_head "parallax-intake.sh"
out="$WORK/intake.txt"
( cd "$REPO" && "$PLX_ROOT/scripts/parallax-intake.sh" ) > "$out" 2>&1
assert_contains "### Parallax intake" "$out" "emits intake header"
assert_contains "$REPO" "$out" "reports the repo path"
assert_contains "dirty_files: 0" "$out" "clean fixture shows 0 dirty files"

_head "preflight.sh (model-free)"
out="$WORK/preflight.txt"
"$PLX_ROOT/scripts/preflight.sh" --repo "$REPO" > "$out" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then _pass "exits 0 with no required engines"; else _fail "exit $rc"; fi
assert_contains "preflight_ok: yes" "$out" "reports preflight_ok: yes"

_head "preflight.sh rejects a bad repo path"
if "$PLX_ROOT/scripts/preflight.sh" --repo /no/such/repo >/dev/null 2>&1; then
  _fail "should reject missing repo"
else
  _pass "non-zero exit on missing repo"
fi

_head "make-review-prompt.sh"
printf 'Lane brief: check correctness.\n' > "$WORK/brief.md"
printf 'diff --git a/calc.py b/calc.py\n+changed line\n' > "$WORK/artifact.md"
printf 'Task: add an empty-list guard to average().\n' > "$WORK/task.md"
out="$WORK/prompt.txt"
"$PLX_ROOT/scripts/make-review-prompt.sh" \
  --lane correctness --brief "$WORK/brief.md" \
  --artifact "$WORK/artifact.md" --task "$WORK/task.md" --stdout > "$out" 2>&1
assert_contains "### Lane" "$out" "emits prompt skeleton"
assert_contains "correctness" "$out" "carries the lane"
assert_contains "empty-list guard" "$out" "carries the task text"
assert_contains "Location, Object, Stage" "$out" "review lane gets finding shape"

_head "make-review-prompt.sh rejects a bad lane"
if "$PLX_ROOT/scripts/make-review-prompt.sh" --lane bogus \
     --brief "$WORK/brief.md" --artifact "$WORK/artifact.md" --task "$WORK/task.md" --stdout >/dev/null 2>&1; then
  _fail "should reject unknown lane"
else
  _pass "non-zero exit on unknown lane"
fi

if [ "$WITH_ENGINES" -eq 1 ]; then
  _head "engine probes (--with-engines)"
  if command -v codex >/dev/null 2>&1; then
    if "$PLX_ROOT/scripts/preflight.sh" --repo "$REPO" --require-codex >/dev/null 2>&1; then
      _pass "codex preflight ok"
    else
      _fail "codex present but preflight failed"
    fi
  else
    _skip "codex not installed — skipped"
  fi
  if command -v grok >/dev/null 2>&1; then
    if "$PLX_ROOT/scripts/preflight.sh" --repo "$REPO" --require-grok >/dev/null 2>&1; then
      _pass "grok preflight ok"
    else
      _skip "grok present but probe failed (known env-dependent)"
    fi
  else
    _skip "grok not installed — skipped"
  fi
else
  _head "engine probes"
  _skip "skipped (pass --with-engines to probe codex/grok)"
fi

summary
