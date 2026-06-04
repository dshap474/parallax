#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"
ROOT="$(pwd)"

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"

BRANCH="$(git branch --show-current 2>/dev/null || echo unknown)"
HEAD="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
DIRTY_COUNT="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

CODEX_PATH="$(command -v codex || true)"
GROK_PATH="$(command -v grok || true)"

{
  echo "### Parallax intake"
  echo "- run_id: $RUN_ID"
  echo "- repo: $ROOT"
  echo "- branch: $BRANCH"
  echo "- head: $HEAD"
  echo "- dirty_files: $DIRTY_COUNT"
  echo "- codex_present: $([ -n "$CODEX_PATH" ] && echo yes || echo no)"
  echo "- grok_present: $([ -n "$GROK_PATH" ] && echo yes || echo no)"
  echo
  echo "### Git status"
  git status --short 2>/dev/null | sed -n '1,80p' || true
}
