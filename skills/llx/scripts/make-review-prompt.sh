#!/usr/bin/env bash
set -euo pipefail

LANE=""
BRIEF=""
ARTIFACT=""
TASK=""
OUT=""
REPO_GUIDANCE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lane) LANE="$2"; shift 2 ;;
    --brief) BRIEF="$2"; shift 2 ;;
    --artifact) ARTIFACT="$2"; shift 2 ;;
    --task) TASK="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --repo-guidance) REPO_GUIDANCE="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$LANE" in
  debug|correctness|refine|plan-review|plan) ;;
  *) echo "--lane must be debug, correctness, refine, plan-review, or plan" >&2; exit 2 ;;
esac

[[ -s "$BRIEF" ]] || { echo "brief missing/empty: $BRIEF" >&2; exit 2; }
[[ -s "$ARTIFACT" ]] || { echo "artifact missing/empty: $ARTIFACT" >&2; exit 2; }
[[ -s "$TASK" ]] || { echo "task missing/empty: $TASK" >&2; exit 2; }
[[ -n "$OUT" ]] || { echo "--out required" >&2; exit 2; }
if [[ -n "$REPO_GUIDANCE" && ! -s "$REPO_GUIDANCE" ]]; then
  echo "repo guidance missing/empty: $REPO_GUIDANCE" >&2
  exit 2
fi

mkdir -p "$(dirname "$OUT")"

{
  echo "### Lane"
  echo "$LANE"
  echo
  echo "### Lane reference"
  echo "$BRIEF"
  echo
  cat "$BRIEF"
  echo
  echo "### Artifacts"
  cat "$ARTIFACT"
  echo
  echo "### Task / spec source"
  cat "$TASK"
  echo
  echo "### Repo guidance"
  if [[ -n "$REPO_GUIDANCE" ]]; then
    cat "$REPO_GUIDANCE"
  else
    echo "none"
  fi
  echo
  echo "### Output shape"
  if [[ "$LANE" == "plan" ]]; then
    echo "Return Task, Proposed plan, Risks, Acceptance checks."
    echo "The proposed plan must be implementation-ready, scoped to the task, and must preserve Claude as the only writer."
  else
    echo "Return Task, Findings, Rationale, Suggested validation."
    echo "Each finding must include Location, Object, Stage, Action, Severity, Confidence, Evidence, Why it matters, Main-agent instruction."
  fi
} > "$OUT"

echo "OK prompt=$OUT"
