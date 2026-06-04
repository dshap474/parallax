#!/usr/bin/env bash
set -euo pipefail

RUN_DIR=""
REQUIRE_CODEX=0
OPTIONAL_GROK=0
REQUIRE_GROK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir) RUN_DIR="$2"; shift 2 ;;
    --require-codex) REQUIRE_CODEX=1; shift ;;
    --optional-grok) OPTIONAL_GROK=1; shift ;;
    --require-grok) REQUIRE_GROK=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$RUN_DIR" ]] || { echo "--run-dir required" >&2; exit 2; }
mkdir -p "$RUN_DIR"/{prompts,outputs,logs}

REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT_MD="$RUN_DIR/preflight.md"
PREFLIGHT_ENV="$RUN_DIR/preflight.env"

CODEX_OK=0
GROK_OK=0
STATUS=0

probe_codex() {
  if ! command -v codex >/dev/null 2>&1; then
    echo "- codex: missing" >> "$PREFLIGHT_MD"
    echo "PARALLAX_CODEX_OK=0" >> "$PREFLIGHT_ENV"
    return 1
  fi

  printf '%s\n' "reply OK" > "$RUN_DIR/prompts/codex-probe.md"
  if "$SCRIPT_DIR/codex-ro.sh" \
    --repo "$REPO" \
    --prompt "$RUN_DIR/prompts/codex-probe.md" \
    --out "$RUN_DIR/outputs/codex-probe.md" \
    --log "$RUN_DIR/logs/codex-probe.log" \
    --effort low >/dev/null && [[ -s "$RUN_DIR/outputs/codex-probe.md" ]]; then
    echo "- codex: ok" >> "$PREFLIGHT_MD"
    echo "PARALLAX_CODEX_OK=1" >> "$PREFLIGHT_ENV"
    CODEX_OK=1
    return 0
  fi

  echo "- codex: probe failed; see $RUN_DIR/logs/codex-probe.log" >> "$PREFLIGHT_MD"
  echo "PARALLAX_CODEX_OK=0" >> "$PREFLIGHT_ENV"
  return 1
}

probe_grok() {
  if ! command -v grok >/dev/null 2>&1; then
    echo "- grok: missing" >> "$PREFLIGHT_MD"
    echo "PARALLAX_GROK_OK=0" >> "$PREFLIGHT_ENV"
    return 1
  fi

  printf '%s\n' "reply OK" > "$RUN_DIR/prompts/grok-probe.md"
  if "$SCRIPT_DIR/grok-ro.sh" \
    --repo "$REPO" \
    --prompt "$RUN_DIR/prompts/grok-probe.md" \
    --out "$RUN_DIR/outputs/grok-probe.txt" \
    --log "$RUN_DIR/logs/grok-probe.log" \
    --effort low >/dev/null && [[ -s "$RUN_DIR/outputs/grok-probe.txt" ]]; then
    echo "- grok: ok" >> "$PREFLIGHT_MD"
    echo "PARALLAX_GROK_OK=1" >> "$PREFLIGHT_ENV"
    GROK_OK=1
    return 0
  fi

  echo "- grok: probe failed or empty output; see $RUN_DIR/logs/grok-probe.log" >> "$PREFLIGHT_MD"
  echo "PARALLAX_GROK_OK=0" >> "$PREFLIGHT_ENV"
  return 1
}

{
  echo "### Parallax preflight"
  echo "- run_dir: $RUN_DIR"
  echo "- repo: $REPO"
} > "$PREFLIGHT_MD"

{
  echo "PARALLAX_PREFLIGHT_RUN_DIR=$RUN_DIR"
  echo "PARALLAX_PREFLIGHT_REPO=$REPO"
} > "$PREFLIGHT_ENV"

if [[ "$REQUIRE_CODEX" -eq 1 ]]; then
  probe_codex || STATUS=1
fi

if [[ "$REQUIRE_GROK" -eq 1 ]]; then
  probe_grok || STATUS=1
elif [[ "$OPTIONAL_GROK" -eq 1 ]]; then
  probe_grok || true
fi

{
  echo "PARALLAX_PREFLIGHT_OK=$([[ "$STATUS" -eq 0 ]] && echo 1 || echo 0)"
  echo "PARALLAX_CODEX_OK=$CODEX_OK"
  echo "PARALLAX_GROK_OK=$GROK_OK"
} >> "$PREFLIGHT_ENV"

cat "$PREFLIGHT_MD"
exit "$STATUS"
