#!/usr/bin/env bash
# Print a host package's skill pipeline without invoking an engine.
# Usage: tests/explain-skill.sh <claude|codex> [skill-name]
set -uo pipefail

# --------------------------------------------------------------------------- #
# Arguments and package paths
# --------------------------------------------------------------------------- #

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${1:-}"
SKILL_NAME="${2:-}"
case "$HOST" in
  claude|codex) ;;
  *) echo "usage: tests/explain-skill.sh <claude|codex> [skill-name]" >&2; exit 2 ;;
esac
PACKAGE="$ROOT/plugins/$HOST/plx"
YAML="$PACKAGE/config/parallax.yaml"

# --------------------------------------------------------------------------- #
# Listing and explanation
# --------------------------------------------------------------------------- #

description_of() {
  sed -n 's/^description:[[:space:]]*//p' "$1" | head -1 | sed 's/^"//; s/"$//'
}

list_skills() {
  echo "$HOST skills:"
  for skill in "$PACKAGE"/skills/*/SKILL.md; do
    name="$(basename "$(dirname "$skill")")"
    printf '  %-18s %s\n' "$name" "$(description_of "$skill" | cut -c1-90)"
  done
}

if [ -z "$SKILL_NAME" ]; then
  list_skills
  exit 0
fi

SKILL="$PACKAGE/skills/$SKILL_NAME/SKILL.md"
if [ ! -f "$SKILL" ]; then
  echo "no such $HOST skill: $SKILL_NAME" >&2
  list_skills >&2
  exit 2
fi

echo "host: $HOST"
echo "skill: $SKILL_NAME"
grep -m1 '^name:' "$SKILL"
printf 'description: %s\n' "$(description_of "$SKILL")"
echo
KEY="$(grep -oE 'key `[a-z-]+`' "$SKILL" | head -1 | sed -E 's/key `([a-z-]+)`/\1/')"
if [ -n "$KEY" ]; then
  echo "config key: $KEY ($HOST config/parallax.yaml)"
  echo "resolved engine bindings:"
  awk -v key="$KEY" '
    /^pipelines:/ {inside=1; next}
    inside && $0 ~ "^  " key ":" {found=1; print "  "$0; next}
    found && /^  [a-zA-Z]/ && $0 !~ /^    / {found=0}
    found {print "  "$0}
  ' "$YAML"
else
  echo "config key: (none — router, scaffold, or passthrough)"
fi
PF="$(grep -oE 'plx-preflight[^`]*' "$SKILL" | head -1)"
if [ -n "$PF" ]; then
  echo "preflight: $PF"
else
  echo "preflight: (none — skipped by this skill)"
fi
echo
echo "sections:"
grep '^## ' "$SKILL" | sed 's/^## /  /'
echo
echo "pipeline:"
awk '
  /^## Pipeline/ {found=1}
  found && (/^Task:/ || /^Request:/ || /^\$ARGUMENTS/) {exit}
  found {print}
' "$SKILL"
