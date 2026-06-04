#!/usr/bin/env bash
set -euo pipefail

MODEL="gpt-5.5"
EFFORT="high"
REPO=""
PROMPT=""
OUT=""
LOG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --effort) EFFORT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$REPO" ]] || { echo "repo not found: $REPO" >&2; exit 2; }
[[ -s "$PROMPT" ]] || { echo "prompt missing/empty: $PROMPT" >&2; exit 2; }
[[ -n "$OUT" ]] || { echo "--out required" >&2; exit 2; }
[[ -n "$LOG" ]] || { echo "--log required" >&2; exit 2; }

mkdir -p "$(dirname "$OUT")" "$(dirname "$LOG")"

codex exec --ignore-user-config --sandbox read-only --skip-git-repo-check \
  -C "$REPO" -m "$MODEL" -c model_reasoning_effort="$EFFORT" --ephemeral \
  -o "$OUT" - < "$PROMPT" > "$LOG" 2>&1

[[ -s "$OUT" ]] || { echo "codex produced empty output: $OUT" >&2; exit 1; }

echo "OK codex-ro out=$OUT log=$LOG"
