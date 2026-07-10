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
for r in reviewer-correctness reviewer-cleanup reviewer-structural planner plan-critic worker engines; do
  if [ -s "$PLX_ROOT/prompts/$r.md" ]; then _pass "prompts/$r.md"; else _fail "missing rubric: prompts/$r.md"; fi
done

_head "Skills are self-contained (no pointers into lib/, prompts/, scripts/, or router.md)"
if grep -rqE 'lib/(pipeline|engines)\.md|prompts/|scripts/|router\.md' "$PLX_ROOT"/skills/*/SKILL.md; then
  _fail "a skill still points at lib/, prompts/, scripts/, or router.md"
else
  _pass "no skill references lib/, prompts/, scripts/, or router.md"
fi

summary
