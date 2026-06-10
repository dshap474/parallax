#!/usr/bin/env bash
# Dry run: show what a skill WOULD do, without running any engine.
# Surfaces the pipeline text, the config key it reads, the resolved engine
# bindings, the prompt blocks it composes, and its preflight requirement.
#
# Usage:
#   tests/explain-skill.sh              # list available skills
#   tests/explain-skill.sh team-dev     # explain one skill
set -uo pipefail
PLX_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
YAML="$PLX_ROOT/config/parallax.yaml"

# Extract a skill's description, following a YAML folded scalar (>- / >).
desc_of() {
  awk '
    /^description:/ {
      sub(/^description:[[:space:]]*/, "")
      if ($0 == ">-" || $0 == ">" || $0 == "|" || $0 == "") { getline; sub(/^[[:space:]]+/, "") }
      gsub(/^"|"$/, "")
      print; exit
    }' "$1"
}

list_skills() {
  echo "Skills (pass one as an argument to dry-run it):"
  for d in "$PLX_ROOT"/skills/*/; do
    name="$(basename "$d")"
    [ -f "$d/SKILL.md" ] || continue
    desc="$(desc_of "$d/SKILL.md" | cut -c1-90)"
    printf '  %-12s %s\n' "$name" "$desc"
  done
}

if [ $# -eq 0 ]; then
  list_skills
  exit 0
fi

SKILL_DIR="$PLX_ROOT/skills/$1"
SKILL="$SKILL_DIR/SKILL.md"
if [ ! -f "$SKILL" ]; then
  echo "no such skill: $1" >&2
  echo >&2
  list_skills >&2
  exit 2
fi

bar() { printf '────────────────────────────────────────────────────────\n'; }

bar
echo "SKILL  $1"
bar
grep -m1 -E '^name:' "$SKILL" | sed 's/^/  /'
printf '  desc: %s\n' "$(desc_of "$SKILL" | cut -c1-200)"

# A router selects a pipeline at runtime instead of binding one config key.
IS_ROUTER=0
grep -q '^## Pipeline selection' "$SKILL" && IS_ROUTER=1

# Config key + resolved engines.
KEY="$(grep -oE 'key `[a-z-]+`' "$SKILL" | head -1 | sed -E 's/key `([a-z-]+)`/\1/')"
echo
if [ "$IS_ROUTER" -eq 1 ]; then
  echo "  type: ROUTER — selects one pipeline per its '## Pipeline selection' section, then runs that skill's pipeline"
  echo "  routes to:"
  grep -oE '`(dev|plan|review)`(\*\*)? \(config key `[a-z-]+`\)' "$SKILL" | sed 's/\*\*//; s/^/    /' || true
elif [ -n "$KEY" ]; then
  echo "  config key: $KEY  (config/parallax.yaml)"
  echo "  resolved engine bindings:"
  awk -v key="$KEY" '
    /^pipelines:/ {inp=1; next}
    inp && $0 ~ "^  " key ":" {found=1; print "    "$0; next}
    found && /^  [a-zA-Z]/ && $0 !~ /^    / {found=0}
    found {print "    "$0}
  ' "$YAML"
else
  echo "  config key: (none — scaffold or single-engine passthrough)"
fi

# Preflight requirement.
echo
PF="$(grep -oE 'plx-preflight[^`]*' "$SKILL" | head -1)"
if [ -n "$PF" ]; then echo "  preflight: $PF"; else echo "  preflight: (none — skipped by this skill)"; fi

# Lane briefs inlined in the skill (skills are self-contained — no external prompt files).
echo
echo "  inline sections:"
secs="$(grep -E '^## ' "$SKILL" | sed 's/^## //')"
if [ -n "$secs" ]; then printf '%s\n' "$secs" | sed 's/^/    /'; else echo "    (none)"; fi

# The pipeline section, verbatim — this is the ordered plan the orchestrator runs.
echo
bar
echo "PIPELINE (verbatim — the steps the orchestrator executes)"
bar
awk '
  /^## Pipeline/ {f=1}
  f && (/^Task:/ || /^Request:/ || /^\$ARGUMENTS/) {exit}
  f {print}
' "$SKILL" | sed 's/^/  /'

if ! grep -qE '^## Pipeline' "$SKILL"; then
  if [ "$IS_ROUTER" -eq 1 ]; then
    echo "  (no '## Pipeline' here — the router runs the chosen skill's pipeline; dry-run that skill to see its steps)"
  else
    echo "  (no '## Pipeline' section — this is a scaffold or a single-engine passthrough)"
  fi
fi
echo
