#!/usr/bin/env bash
set -euo pipefail

# Write-capable Grok wrapper. Unlike grok-ro.sh (plan permission mode), this lets
# Grok EDIT files in the target repo. It is used only when parallax.yaml assigns a
# non-Claude engine to the writer (`code`) role. Safety: `acceptEdits` permission
# mode (file edits scoped to --cwd; does NOT grant arbitrary command execution),
# never bypassPermissions, never --yolo.
#
# KNOWN LIMITATION (verified 2026-06-04, grok 0.2.16): Grok's file-editing happens
# in background workers that die with `AuthorizationRequired / Transport channel
# closed` even with the Bash sandbox disabled — so writes silently produce nothing.
# This wrapper therefore FAILS LOUDLY on that signature instead of exiting 0 with no
# edit. `code: grok` is unsupported until that grok-CLI auth issue is resolved; use
# `code: claude` or `code: codex` for the writer. (Grok works fine as a read-only
# REVIEWER via grok-ro.sh, where only the main worker's text is needed.)
#
# Same sandbox caveat as grok-ro.sh: the orchestrator must disable its own Bash
# sandbox for this call (Claude Code: dangerouslyDisableSandbox: true).

EFFORT="high"
REPO=""
PROMPT=""
OUT=""
LOG=""
STDOUT=0
TMP_DIR=""

cleanup() {
  if [[ -n "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --stdout) STDOUT=1; shift ;;
    --effort) EFFORT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$REPO" ]] || { echo "repo not found: $REPO" >&2; exit 2; }
[[ -s "$PROMPT" ]] || { echo "prompt missing/empty: $PROMPT" >&2; exit 2; }
if [[ "$STDOUT" -eq 1 ]]; then
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/parallax-grok-rw.XXXXXX")"
  OUT="$TMP_DIR/output.txt"
  LOG="$TMP_DIR/grok.log"
else
  [[ -n "$OUT" ]] || { echo "--out required" >&2; exit 2; }
  [[ -n "$LOG" ]] || { echo "--log required" >&2; exit 2; }
fi

mkdir -p "$(dirname "$OUT")" "$(dirname "$LOG")"

if ! grok --cwd "$REPO" --permission-mode acceptEdits --reasoning-effort "$EFFORT" \
  --prompt-file "$PROMPT" > "$OUT" 2>"$LOG"; then
  echo "grok invocation failed" >&2
  [[ -s "$LOG" ]] && sed -n '1,40p' "$LOG" >&2
  exit 1
fi

# Detect the worker-auth failure: grok exits 0 but the editing workers died, so no
# files were written. Fail loudly instead of reporting a phantom success.
if grep -qE "AuthorizationRequired|Transport channel closed" "$LOG"; then
  echo "grok-rw: editing workers failed with AuthorizationRequired — no files written." >&2
  echo "grok-rw: \`code: grok\` is unsupported in this environment; use code: claude or code: codex." >&2
  sed -n '1,20p' "$LOG" >&2
  exit 1
fi

[[ -s "$OUT" ]] || { echo "grok produced empty output: $OUT" >&2; exit 1; }

if [[ "$STDOUT" -eq 1 ]]; then
  cat "$OUT"
else
  echo "OK grok-rw out=$OUT log=$LOG"
fi
