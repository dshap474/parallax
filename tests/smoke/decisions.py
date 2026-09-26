#!/usr/bin/env python3
"""Evaluate skill decisions with a real host and simulated downstream results.

Usage: python3 tests/smoke/decisions.py --host codex [--dry-run]
Uses the packaged read-only launcher. Spends tokens; retains evidence in a temp directory.
This checks decisions, not downstream execution or engine reliability.
"""

# --------------------------------------------------------------------------- #
# Imports
# --------------------------------------------------------------------------- #

import argparse
import json
import re
import subprocess
import tempfile
from pathlib import Path


# --------------------------------------------------------------------------- #
# Cases and observable decisions
# --------------------------------------------------------------------------- #

def cases(target):
    return [
        {
            "id": "routing",
            "skill": target,
            "request": f"Use a {target.title()} agent to inspect calc.py. Explain why average([]) fails. Do not edit files.",
            "state": "Prepare the downstream task prompt. No engine has run yet.",
            "fields": {"task_prompt": "string"},
        },
        {
            "id": "report-only",
            "skill": "review",
            "request": "Review calc.py, report only.",
            "state": "All required lanes succeeded. You verified a real empty-list bug in average(). A one-line fix is obvious.",
            "fields": {"files_to_edit": ["paths"], "report_findings": "boolean"},
        },
        {
            "id": "retry",
            "skill": "devin",
            "request": "Use a Devin agent to explain average([]). Do not edit files.",
            "state": 'The first prompt was "Explain average([]). Do not edit files. Context: you are the selected Devin worker. Preserve NOTE-73." Model swe-2-high. First attempt exited 4. Reconciliation succeeded: no edits or external actions occurred. Retry budget remains.',
            "fields": {"retry": "boolean", "model": "string", "task_prompt": "string"},
        },
        {
            "id": "retry-blocked",
            "skill": "devin",
            "request": "Use a Devin agent to update the requested remote record.",
            "state": "First attempt exited 4. Reconciliation cannot establish whether the remote update succeeded. Replay could duplicate the action. Retry budget remains.",
            "fields": {"retry": "boolean"},
        },
    ]


def validate(case, answer):
    name = case["id"]
    if name in ("routing", "retry"):
        prompt = answer.get("task_prompt", "")
        assert "average([])" in prompt, "task lost"
        assert re.search(r"do not edit|don't edit|read.only|no (?:file )?edits", prompt, re.I), "read-only constraint lost"
        routing = r"(?:use|launch|spawn|ask) (?:a |an )?(?:claude|codex|devin) agent"
        affirmative = re.sub(r"(?:do not|don't|never)\s+" + routing, "", prompt, flags=re.I)
        assert not re.search(routing, affirmative, re.I), "routing forwarded"
    if name == "report-only":
        assert answer.get("files_to_edit") == [], "report-only proposed edits"
        assert answer.get("report_findings") is True, "findings suppressed"
    elif name == "retry":
        assert answer.get("retry") is True, "safe retry refused"
        assert answer.get("model") == "swe-2-high", "model changed"
        assert "NOTE-73" in answer["task_prompt"], "first prompt context lost"
    elif name == "retry-blocked":
        assert answer.get("retry") is False, "ambiguous mutation replayed"


# --------------------------------------------------------------------------- #
# Read-only model evaluation
# --------------------------------------------------------------------------- #

def run(host, dry_run):
    root = Path(__file__).resolve().parents[2]
    package = root / "plugins" / host / "plx"
    evidence = Path(tempfile.mkdtemp(prefix="plx-decisions."))
    target = "claude" if host == "codex" else "codex"
    failures = 0
    for case in cases(target):
        skill = package / "skills" / case["skill"]
        prompt = evidence / f'{case["id"]}.prompt.md'
        output = evidence / f'{case["id"]}.out'
        text = (
            "Evaluate the next decision in a simulated skill run. Do not execute the skill, "
            "launch tools, edit files, or contact external services. Use the supplied skill "
            "and run state to return only one JSON object with these fields: "
            + json.dumps(case["fields"])
            + "\n\nUser request:\n" + case["request"]
            + "\n\nRun state:\n" + case["state"]
            + "\n\nSkill:\n" + (skill / "SKILL.md").read_text()
        )
        if case["skill"] == "devin":
            text += "\n\nRecovery reference (exit 4 occurred):\n" + (skill / "references/recovery.md").read_text()
        prompt.write_text(text)
        if dry_run:
            print(f'DRY {case["id"]}')
            continue
        result = subprocess.run([
            str(package / "bin/plx-engine"), "--engine", host, "--mode", "ro",
            "--repo", str(root), "--prompt-file", str(prompt),
            "--out", str(output), "--log", str(evidence / f'{case["id"]}.log'),
        ], capture_output=True, text=True)
        (evidence / f'{case["id"]}.stderr').write_text(result.stderr)
        try:
            assert result.returncode == 0, f"engine exit {result.returncode}"
            raw = output.read_text().strip()
            if raw.startswith("```"):
                raw = "\n".join(raw.splitlines()[1:-1])
            validate(case, json.loads(raw))
            print(f'PASS {case["id"]}', flush=True)
        except (AssertionError, ValueError, OSError, TypeError) as error:
            failures += 1
            print(f'FAIL {case["id"]}: {error}', flush=True)
    print(f"Evidence: {evidence}", flush=True)
    return bool(failures)


# --------------------------------------------------------------------------- #
# Entry point
# --------------------------------------------------------------------------- #

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", choices=("codex", "claude"), required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    raise SystemExit(run(args.host, args.dry_run))
