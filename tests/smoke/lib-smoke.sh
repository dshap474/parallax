#!/usr/bin/env bash
# Helpers for the BEHAVIORAL smoke suite (tests/smoke/).
# tests/lib.sh is the static/model-free harness; this adds the bits the behavioral
# suite needs: fixture resolution, a per-run log dir, a cross-layer summary table,
# and a cached engine-auth gate. Source AFTER computing your own dir.
# Bash 3.2 safe (no associative arrays, no mapfile).

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
SMOKE_DIR="$PLX_ROOT/tests/smoke"

# fixture_dir <name> -> absolute source dir for that fixture.
fixture_dir() {
  case "$1" in
    calc) printf '%s\n' "$PLX_ROOT/tests/fixture" ;;
    bare) printf '%s\n' "$SMOKE_DIR/fixtures/bare" ;;
    *) echo "unknown fixture: $1" >&2; return 2 ;;
  esac
}

# smoke_run_dir -> the timestamped log dir for this run. If run-smoke.sh already
# created one (PLX_SMOKE_RUNDIR), reuse it so both layers share a dir.
smoke_run_dir() {
  if [ -n "${PLX_SMOKE_RUNDIR:-}" ]; then mkdir -p "$PLX_SMOKE_RUNDIR"; printf '%s\n' "$PLX_SMOKE_RUNDIR"; return; fi
  local d; d="$SMOKE_DIR/logs/$(date +%Y-%m-%dT%H-%M-%S)"; mkdir -p "$d"; printf '%s\n' "$d"
}

# smoke_summary_row <rundir> <layer> <item> <verdict> <note>
smoke_summary_row() {
  local f="$1/summary.md"
  [ -f "$f" ] || printf '# Parallax smoke run\n\n| Layer | Item | Verdict | Note |\n|---|---|---|---|\n' > "$f"
  printf '| %s | %s | %s | %s |\n' "$2" "$3" "$4" "$5" >> "$f"
}

# preflight_ok <engine> -> 0 if that engine is installed AND authed (cached per process).
ENGINE_OK=""; ENGINE_NO=""
preflight_ok() {
  case " $ENGINE_OK " in *" $1 "*) return 0 ;; esac
  case " $ENGINE_NO " in *" $1 "*) return 1 ;; esac
  local r; r="$(make_tmp_repo)"
  if "$PLUGIN_ROOT/bin/plx-preflight" --repo "$r" --require-"$1" >/dev/null 2>&1; then
    ENGINE_OK="$ENGINE_OK $1"; rm -rf "$r"; return 0
  fi
  ENGINE_NO="$ENGINE_NO $1"; rm -rf "$r"; return 1
}
