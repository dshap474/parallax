#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
RUN_DIR=".parallax/runs/$RUN_ID"

mkdir -p "$RUN_DIR"/{prompts,outputs,logs,findings,artifacts}

BRANCH="$(git branch --show-current 2>/dev/null || echo unknown)"
HEAD="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
DIRTY_COUNT="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

CODEX_PATH="$(command -v codex || true)"
GROK_PATH="$(command -v grok || true)"

{
  echo "PARALLAX_RUN_ID=$RUN_ID"
  echo "PARALLAX_RUN_DIR=$RUN_DIR"
  echo "PARALLAX_REPO=$ROOT"
  echo "PARALLAX_BRANCH=$BRANCH"
  echo "PARALLAX_HEAD=$HEAD"
  echo "PARALLAX_DIRTY_COUNT=$DIRTY_COUNT"
  echo "PARALLAX_CODEX_PRESENT=$([ -n "$CODEX_PATH" ] && echo 1 || echo 0)"
  echo "PARALLAX_GROK_PRESENT=$([ -n "$GROK_PATH" ] && echo 1 || echo 0)"
} > "$RUN_DIR/state.env"

{
  echo "### Parallax intake"
  echo "- run_id: $RUN_ID"
  echo "- run_dir: $RUN_DIR"
  echo "- repo: $ROOT"
  echo "- branch: $BRANCH"
  echo "- head: $HEAD"
  echo "- dirty_files: $DIRTY_COUNT"
  echo "- codex_present: $([ -n "$CODEX_PATH" ] && echo yes || echo no)"
  echo "- grok_present: $([ -n "$GROK_PATH" ] && echo yes || echo no)"
  echo
  echo "### Git status"
  git status --short 2>/dev/null | sed -n '1,80p' || true
} | tee "$RUN_DIR/intake.md"
