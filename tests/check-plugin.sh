#!/usr/bin/env bash
# Validate both Parallax packages without invoking any model engine.
# Usage: tests/check-plugin.sh
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

# --------------------------------------------------------------------------- #
# Manifests and versions
# --------------------------------------------------------------------------- #

_head "Marketplace and plugin manifests"
for file in \
  .claude-plugin/marketplace.json \
  .agents/plugins/marketplace.json \
  plugins/claude/plx/.claude-plugin/plugin.json \
  plugins/codex/plx/.codex-plugin/plugin.json; do
  if python3 -m json.tool "$PLX_ROOT/$file" >/dev/null 2>&1; then
    _pass "$file"
  else
    _fail "missing or invalid JSON: $file"
  fi
done

version_of() {
  sed -n 's/^[[:space:]]*"version": "\([^"]*\)".*/\1/p' "$1" | head -1
}

claude_version="$(version_of "$PLX_CLAUDE/.claude-plugin/plugin.json")"
codex_version="$(version_of "$PLX_CODEX/.codex-plugin/plugin.json")"
market_version="$(version_of "$PLX_ROOT/.claude-plugin/marketplace.json")"
if [ "$claude_version" = "0.5.0" ] && [ "$claude_version" = "$codex_version" ] &&
   [ "$claude_version" = "$market_version" ] &&
   grep -qx "v$claude_version" "$PLX_ROOT/README.md" &&
   grep -qx "Status: v$claude_version" "$PLX_ROOT/docs/SPEC.md"; then
  _pass "release surfaces agree at $claude_version"
else
  _fail "release version drift"
fi

# --------------------------------------------------------------------------- #
# Skill surfaces and polarity
# --------------------------------------------------------------------------- #

_head "Nine host-native skills per package"
claude_count="$(find "$PLX_CLAUDE/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"
codex_count="$(find "$PLX_CODEX/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"
[ "$claude_count" = 9 ] && _pass "Claude skills: 9" || _fail "Claude skills: $claude_count"
[ "$codex_count" = 9 ] && _pass "Codex skills: 9" || _fail "Codex skills: $codex_count"

for skill in "$PLX_CLAUDE"/skills/*/SKILL.md; do
  grep -qE '^name:[[:space:]]*"?plx::' "$skill" && _pass "Claude $(basename "$(dirname "$skill")")" || _fail "bad Claude name: $skill"
done
for skill in "$PLX_CODEX"/skills/*/SKILL.md; do
  name="$(basename "$(dirname "$skill")")"
  grep -qE '^name:[[:space:]]*plx-[a-z-]+$' "$skill" || _fail "bad Codex name: $skill"
  metadata="$(dirname "$skill")/agents/openai.yaml"
  if [ -f "$metadata" ] && grep -q 'allow_implicit_invocation: false' "$metadata"; then
    _pass "Codex $name explicit-only"
  else
    _fail "Codex $name missing explicit-only metadata"
  fi
done

if [ -f "$PLX_CLAUDE/skills/codex/SKILL.md" ] &&
   [ -f "$PLX_CODEX/skills/claude/SKILL.md" ] &&
   [ ! -e "$PLX_CODEX/skills/codex" ]; then
  _pass "opposite-host passthroughs are platform-correct"
else
  _fail "opposite-host passthrough contract is wrong"
fi

if grep -q '^    code: codex$' "$PLX_CODEX/config/parallax.yaml" &&
   [ "$(grep -c '\[claude\]' "$PLX_CODEX/config/parallax.yaml")" -ge 6 ] &&
   [ "$(grep -c '\[codex\]' "$PLX_CLAUDE/config/parallax.yaml")" -ge 6 ]; then
  _pass "engine polarity is host-specific"
else
  _fail "engine polarity drift"
fi

if grep -qE 'fable-5|Codex review lanes|Standalone Codex plan critics|implementation critic \(codex' \
  "$PLX_ROOT/shared/prompts/engines.md"; then
  _fail "shared engine guidance contains Claude-host assumptions"
else
  _pass "shared engine guidance is host-neutral"
fi

codex_review_sizing="$(grep -A1 'claude + grok — six lanes), at' "$PLX_CODEX/skills/review/SKILL.md")"
if [ -n "$codex_review_sizing" ] &&
   printf '%s\n' "$codex_review_sizing" | grep -q '`high`' &&
   ! printf '%s\n' "$codex_review_sizing" | grep -q '`xhigh`' &&
   grep -q 'claude high + grok high' "$PLX_CODEX/skills/review/SKILL.md" &&
   ! grep -q 'codex + grok' "$PLX_CODEX/skills/review/SKILL.md"; then
  _pass "Codex review examples preserve opposite-engine polarity"
else
  _fail "Codex review examples contradict configured polarity"
fi

# --------------------------------------------------------------------------- #
# Runtime packaging
# --------------------------------------------------------------------------- #

_head "Shared runtime copies"
if "$PLX_ROOT/scripts/sync-shared.sh" --check >/dev/null; then
  _pass "shared bin/prompts/license copies are current"
else
  _fail "shared runtime drift"
fi

SYNC_TMP="$(mktemp -d "${TMPDIR:-/tmp}/plx-sync-check.XXXXXX")"
trap 'rm -rf "$SYNC_TMP"' EXIT
SYNC_REPO="$SYNC_TMP/repo"
mkdir -p "$SYNC_REPO/scripts" "$SYNC_REPO/plugins/claude/plx" "$SYNC_REPO/plugins/codex/plx"
cp -R "$PLX_ROOT/shared" "$SYNC_REPO/shared"
cp "$PLX_ROOT/LICENSE" "$SYNC_REPO/LICENSE"
cp "$PLX_ROOT/scripts/sync-shared.sh" "$SYNC_REPO/scripts/sync-shared.sh"
"$SYNC_REPO/scripts/sync-shared.sh" >/dev/null
printf 'orphan\n' > "$SYNC_REPO/plugins/codex/plx/prompts/orphan.md"
orphan_output="$("$SYNC_REPO/scripts/sync-shared.sh" --check 2>&1)"
orphan_rc=$?
if [ "$orphan_rc" -eq 1 ] && printf '%s\n' "$orphan_output" | grep -q 'orphan: plugins/codex/plx/prompts/orphan.md'; then
  _pass "shared check rejects destination-only files"
else
  _fail "shared check missed a destination-only file"
fi
"$SYNC_REPO/scripts/sync-shared.sh" >/dev/null
if [ ! -e "$SYNC_REPO/plugins/codex/plx/prompts/orphan.md" ]; then
  _pass "shared sync prunes destination-only files"
else
  _fail "shared sync left a destination-only file"
fi

for package in "$PLX_CLAUDE" "$PLX_CODEX"; do
  label="$(basename "$(dirname "$package")")"
  for tool in plx-engine plx-preflight plx-config plx-skill plx-link-claude; do
    [ -x "$package/bin/$tool" ] && _pass "$label bin/$tool" || _fail "$label bin/$tool"
  done
  for rubric in engines planner plan-critic-implementation plan-critic-system worker reviewer-correctness reviewer-cleanup reviewer-structural; do
    [ -s "$package/prompts/$rubric.md" ] || _fail "$label missing rubric $rubric"
  done
done

if grep -RqiE 'use subagents|spawn (a |an )?subagent' "$PLX_ROOT/plugins"; then
  _fail "a skill still instructs subagent orchestration"
else
  _pass "no skill instructs subagent orchestration"
fi
if find "$PLX_ROOT/plugins" -type d -name .parallax | grep -q .; then
  _fail "repo-local runtime state exists"
else
  _pass "no .parallax runtime state"
fi
if grep -RE '^[[:space:]]*[^#].*(danger-full-access|dangerously-bypass-approvals-and-sandbox|--yolo)' \
  "$PLX_ROOT/shared/bin" >/dev/null; then
  _fail "forbidden broad-permission flag in shared runtime"
else
  _pass "shared runtime rejects broad-permission patterns"
fi

# --------------------------------------------------------------------------- #
# Maintainer helper contracts
# --------------------------------------------------------------------------- #

_head "Maintainer helper contracts"
"$PLX_ROOT/tests/smoke-scripts.sh" codex >/dev/null 2>&1
smoke_rc=$?
"$PLX_ROOT/tests/smoke-scripts.sh" --with-engines codex >/dev/null 2>&1
smoke_extra_rc=$?
if [ "$smoke_rc" -eq 2 ] && [ "$smoke_extra_rc" -eq 2 ]; then
  _pass "smoke harness rejects positional package selectors"
else
  _fail "smoke harness silently accepted a positional package selector"
fi

explain_output="$("$PLX_ROOT/tests/explain-skill.sh" codex dev)"
if printf '%s\n' "$explain_output" | grep -q 'config key: dev' &&
   printf '%s\n' "$explain_output" | grep -q 'review-correctness: \[claude\]' &&
   printf '%s\n' "$explain_output" | grep -q '^preflight: plx-preflight'; then
  _pass "skill explanation resolves Codex bindings and preflight"
else
  _fail "skill explanation omitted Codex bindings or preflight"
fi

summary
