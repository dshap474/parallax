#!/usr/bin/env bash
# Static integrity of the Parallax plugin. No model calls — pure wiring checks.
# Catches the drift this plugin is prone to: mismatched release versions, dangling
# ${CLAUDE_PLUGIN_ROOT} paths, missing config keys/tools/rubrics, and retired subagents.
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

_head "Manifests are valid JSON"
for m in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  if [ -f "$PLX_ROOT/$m" ]; then
    if python3 -m json.tool "$PLX_ROOT/$m" >/dev/null 2>&1; then _pass "$m"; else _fail "invalid JSON: $m"; fi
  else
    _fail "missing: $m"
  fi
done

_head "Release version surfaces agree"
plugin_version="$(sed -n 's/^[[:space:]]*"version": "\([^"]*\)".*/\1/p' "$PLX_ROOT/.claude-plugin/plugin.json" | head -1)"
marketplace_version="$(sed -n 's/^[[:space:]]*"version": "\([^"]*\)".*/\1/p' "$PLX_ROOT/.claude-plugin/marketplace.json" | head -1)"
if [ -n "$plugin_version" ] && [ "$plugin_version" = "$marketplace_version" ]; then
  _pass "plugin.json = marketplace.json = $plugin_version"
else
  _fail "version mismatch: plugin=${plugin_version:-missing} marketplace=${marketplace_version:-missing}"
fi
if grep -qx "v$plugin_version" "$PLX_ROOT/README.md" &&
   grep -q "^Status: v$plugin_version$" "$PLX_ROOT/docs/SPEC.md" &&
   grep -q "\"version\": \"$plugin_version\"" "$PLX_ROOT/docs/SPEC.md"; then
  _pass "README.md and docs/SPEC.md identify v$plugin_version"
else
  _fail "README.md or docs/SPEC.md release version is stale"
fi

_head "Every skill has frontmatter name"
for s in "$PLX_ROOT"/skills/*/SKILL.md; do
  rel="${s#$PLX_ROOT/}"
  if grep -qE '^name:[[:space:]]*"?plx::' "$s"; then _pass "$rel"; else _fail "no plx:: name in $rel"; fi
done

_head "No \${CLAUDE_PLUGIN_ROOT} in skills (unreliable in prose — bin/ tools are on PATH)"
if grep -rq 'CLAUDE_PLUGIN_ROOT' "$PLX_ROOT/skills" 2>/dev/null; then
  _fail "a skill still uses \${CLAUDE_PLUGIN_ROOT}"
else
  _pass "skills reference bin/ tools by bare name only"
fi

_head "plx-* tools referenced by skills exist in bin/"
while IFS= read -r tool; do
  [ -n "$tool" ] || continue
  if [ -x "$PLX_ROOT/bin/$tool" ]; then _pass "bin/$tool"; else _fail "referenced tool missing: bin/$tool"; fi
done < <(grep -rhoE '`plx-[a-z*-]+' "$PLX_ROOT/skills" 2>/dev/null | tr -d '`' | grep -E '^plx-[a-z]+(-[a-z]+)*$' | sort -u)

_head "Config keys referenced by skills exist in parallax.yaml"
YAML="$PLX_ROOT/config/parallax.yaml"
while IFS= read -r line; do
  key="$(printf '%s' "$line" | sed -E 's/.*key `([a-z-]+)`.*/\1/')"
  [ -n "$key" ] || continue
  if grep -qE "^  ${key}:" "$YAML"; then _pass "config key: $key"; else _fail "skill references missing config key: $key"; fi
done < <(grep -rhoE 'key `[a-z-]+`' "$PLX_ROOT"/skills/*/SKILL.md 2>/dev/null | sort -u)

_head "No subagent execution paths remain (agents/ was retired for headless plx-engine lanes)"
if grep -rqE 'plx:(claude|codex|grok)-[a-z-]+' "$PLX_ROOT/skills" "$PLX_ROOT/config" 2>/dev/null; then
  _fail "a skill or config still references a plx:<engine>-<persona> subagent"
else
  _pass "no plx:<engine>-<persona> references in skills/ or config/"
fi

_head "Grok runtime policy is current"
if grep -rqi 'grok-composer' \
  "$PLX_ROOT/README.md" "$PLX_ROOT/docs" "$PLX_ROOT/prompts" \
  "$PLX_ROOT/skills" "$PLX_ROOT/bin" "$PLX_ROOT/config" \
  "$PLX_ROOT/.project/architecture" 2>/dev/null; then
  _fail "a shipped surface still references Grok Composer"
else
  _pass "no shipped Grok Composer references"
fi

_head "Implementation model policy is current"
if grep -q '^    code: codex$' "$PLX_ROOT/config/parallax.yaml" &&
   [ "$(grep -c '^    code: codex$' "$PLX_ROOT/config/parallax.yaml")" -eq 2 ]; then
  _pass "build and dev default to Codex writers"
else
  _fail "build/dev writer bindings are not both Codex"
fi
if grep -q 'MODEL="gpt-5.6-sol"' "$PLX_ROOT/bin/plx-engine" &&
   grep -q 'EFFORT="medium"' "$PLX_ROOT/bin/plx-engine"; then
  _pass "Codex defaults to GPT-5.6 Sol at medium effort"
else
  _fail "Codex model or effort default is stale"
fi
if grep -q 'GPT-5.5 and Sonnet are forbidden' "$PLX_ROOT/prompts/engines.md"; then
  _pass "engine judgment doc states the forbidden-model rule"
else
  _fail "engine judgment doc omits the forbidden-model rule"
fi
if grep -rqiE 'default (model )?`?gpt-5\.5|code: claude|writer lane.*claude|gpt-5\.5 or grok|opus/sonnet' \
  "$PLX_ROOT/README.md" "$PLX_ROOT/docs" "$PLX_ROOT/prompts" \
  "$PLX_ROOT/skills" "$PLX_ROOT/config" "$PLX_ROOT/.project/architecture" 2>/dev/null; then
  _fail "an active surface still teaches the retired implementation policy"
else
  _pass "no active surface teaches the retired implementation policy"
fi
if grep -rqiE 'use subagents|spawn (a |an )?subagent' "$PLX_ROOT/skills" 2>/dev/null; then
  _fail "a skill or reference still instructs the caller to spawn subagents"
else
  _pass "no skill or reference instructs the caller to spawn subagents"
fi

_head "Rubrics referenced via --rubric exist in prompts/"
while IFS= read -r r; do
  [ -n "$r" ] || continue
  if [ -s "$PLX_ROOT/prompts/$r.md" ]; then _pass "rubric ref: $r"; else _fail "skill references missing rubric: prompts/$r.md"; fi
done < <(grep -rhoE -- '--rubric [a-z-]+' "$PLX_ROOT"/skills/*/SKILL.md 2>/dev/null | awk '{print $2}' | grep -v -- '-$' | sort -u)
# (refs ending in '-' are templated, e.g. `--rubric reviewer-<dimension>` — the
#  expansions are covered by the presence check below)

_head "Engine API tools present and executable"
for sc in plx-engine plx-preflight plx-config plx-skill plx-link-claude; do
  assert_exec "bin/$sc"
done

_head "Lane rubrics present (prompts/, injected by plx-engine --rubric)"
for r in reviewer-correctness reviewer-cleanup reviewer-structural planner plan-critic-implementation plan-critic-system worker engines; do
  if [ -s "$PLX_ROOT/prompts/$r.md" ]; then _pass "prompts/$r.md"; else _fail "missing rubric: prompts/$r.md"; fi
done

_head "Standalone plan critic defaults"
if grep -q -- '--model gpt-5.6-sol --effort xhigh' "$PLX_ROOT/skills/plan/SKILL.md"; then
  _pass "plan pins GPT-5.6 Sol at xhigh"
else
  _fail "plan does not pin GPT-5.6 Sol at xhigh"
fi
if grep -q -- '--effort <resolved-effort>' "$PLX_ROOT/skills/goal-spec/SKILL.md" &&
   grep -q 'Grok uses `high`' "$PLX_ROOT/skills/goal-spec/SKILL.md" &&
   grep -q 'once per \*\*distinct\*\* resolved engine' "$PLX_ROOT/skills/goal-spec/SKILL.md" &&
   grep -q '\[RED-TEAM INCOMPLETE\]' "$PLX_ROOT/skills/goal-spec/SKILL.md"; then
  _pass "goal-spec sizes and preflights every required engine"
else
  _fail "goal-spec engine sizing or required-lane contract is incomplete"
fi
if grep -q 'exactly one' "$PLX_ROOT/skills/plan/SKILL.md" &&
   grep -q 'plan-critic-<dimension>' "$PLX_ROOT/skills/plan/SKILL.md"; then
  _pass "plan requires one engine per critic dimension"
else
  _fail "plan critic cardinality is not explicit"
fi
brief_contract_ok=1
for s in plan dev goal-spec; do
  for heading in '### Original request' '### Confirmed decisions' '### Candidate plan'; do
    grep -q "$heading" "$PLX_ROOT/skills/$s/SKILL.md" || brief_contract_ok=0
  done
done
if [ "$brief_contract_ok" -eq 1 ]; then
  _pass "all plan critics receive the canonical task contract"
else
  _fail "a plan critic consumer has a stale brief shape"
fi
if grep -q 'confirmed decisions' "$PLX_ROOT/prompts/plan-critic-implementation.md" &&
   grep -q 'candidate plan' "$PLX_ROOT/prompts/plan-critic-implementation.md" &&
   grep -q 'confirmed decisions' "$PLX_ROOT/prompts/plan-critic-system.md" &&
   grep -q 'candidate plan' "$PLX_ROOT/prompts/plan-critic-system.md"; then
  _pass "plan critic rubrics consume the canonical contract"
else
  _fail "plan critic rubrics do not match the brief contract"
fi
if grep -q 'once per \*\*distinct\*\* resolved engine' "$PLX_ROOT/skills/plan/SKILL.md" &&
   grep -q 'one retry on the same binding' "$PLX_ROOT/skills/plan/SKILL.md" &&
   grep -q -- '--mode ro' "$PLX_ROOT/skills/plan/SKILL.md" &&
   grep -q '\[RED-TEAM INCOMPLETE\]' "$PLX_ROOT/skills/plan/SKILL.md"; then
  _pass "plan preflight and failure paths are bounded"
else
  _fail "plan preflight or failure contract is incomplete"
fi
if grep -q 'current-message engine substitution' "$PLX_ROOT/skills/plan/SKILL.md" &&
   grep -q 'explicit model/effort settings' "$PLX_ROOT/skills/plan/SKILL.md"; then
  _pass "plan override precedence is explicit"
else
  _fail "plan override precedence is ambiguous"
fi

_head "Skills are self-contained (no pointers into lib/, prompts/, scripts/, or router.md)"
if grep -rqE 'lib/(pipeline|engines)\.md|prompts/|scripts/|router\.md' "$PLX_ROOT"/skills/*/SKILL.md; then
  _fail "a skill still points at lib/, prompts/, scripts/, or router.md"
else
  _pass "no skill references lib/, prompts/, scripts/, or router.md"
fi

summary
