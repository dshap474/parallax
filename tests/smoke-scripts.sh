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

_head "bin tools answer --help"
for t in plx-codex-ro plx-codex-rw plx-grok-ro plx-grok-rw plx-preflight plx-config plx-skill; do
  out="$WORK/help-$t.txt"
  if "$PLX_ROOT/bin/$t" --help > "$out" 2>&1 && grep -q "Usage:" "$out"; then
    _pass "$t --help"
  else
    _fail "$t --help (no Usage block or non-zero exit)"
  fi
done

_head "bin tools reject unknown flags with exit 2"
"$PLX_ROOT/bin/plx-codex-ro" --bogus >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then _pass "plx-codex-ro --bogus exits 2"; else _fail "expected exit 2, got $rc"; fi

_head "plx-config prints the engine config"
out="$WORK/config.txt"
"$PLX_ROOT/bin/plx-config" > "$out" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then _pass "exits 0"; else _fail "exit $rc"; fi
assert_contains "pipelines:" "$out" "emits the pipelines map"

_head "plx-skill prints a pipeline skill"
out="$WORK/skill.txt"
"$PLX_ROOT/bin/plx-skill" dev > "$out" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then _pass "exits 0"; else _fail "exit $rc"; fi
assert_contains "## Pipeline" "$out" "emits the pipeline section"
if "$PLX_ROOT/bin/plx-skill" no-such-skill >/dev/null 2>&1; then
  _fail "should reject unknown skill"
else
  _pass "non-zero exit on unknown skill"
fi
if "$PLX_ROOT/bin/plx-skill" team-dev >/dev/null 2>&1; then
  _fail "should reject disabled skill (team-dev has no SKILL.md)"
else
  _pass "non-zero exit on disabled skill"
fi

_head "plx-preflight (model-free)"
out="$WORK/preflight.txt"
"$PLX_ROOT/bin/plx-preflight" --repo "$REPO" > "$out" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then _pass "exits 0 with no required engines"; else _fail "exit $rc"; fi
assert_contains "preflight_ok: yes" "$out" "reports preflight_ok: yes"

_head "plx-preflight rejects a bad repo path"
if "$PLX_ROOT/bin/plx-preflight" --repo /no/such/repo >/dev/null 2>&1; then
  _fail "should reject missing repo"
else
  _pass "non-zero exit on missing repo"
fi

if [ "$WITH_ENGINES" -eq 1 ]; then
  _head "engine probes (--with-engines)"
  if command -v codex >/dev/null 2>&1; then
    if "$PLX_ROOT/bin/plx-preflight" --repo "$REPO" --require-codex >/dev/null 2>&1; then
      _pass "codex preflight ok"
    else
      _fail "codex present but preflight failed"
    fi
  else
    _skip "codex not installed — skipped"
  fi
  if command -v grok >/dev/null 2>&1; then
    if "$PLX_ROOT/bin/plx-preflight" --repo "$REPO" --require-grok >/dev/null 2>&1; then
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
