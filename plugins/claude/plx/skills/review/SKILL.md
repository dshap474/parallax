---
name: review
description: Review code through independent model lanes and apply confirmed fixes. Use "report only" for findings without edits.
argument-hint: "<scope> [with all Codex|Claude|Grok lanes] [at <effort> effort] [report only]"
disable-model-invocation: true
user-invocable: true
---

# /plx:review

Run independent read-only review lanes, verify their findings, and fix confirmed issues
with small targeted edits. A report-only request stops after synthesis.

Use the packaged helpers on PATH.

## Prepare the round

Establish the requested files, scope mode (change review or whole-file audit), and any
change range and baseline from the user and Git. Read enough code to make the scope
accurate, and note existing uncommitted work so fixes preserve it.

Run three core roles: `reviewer-correctness`, `reviewer-cleanup`, and
`reviewer-structural`. Default all three to Codex `gpt-6.1-sol` at `medium`, matching
`/plx:codex`. An explicit engine, model, or effort (for example `with all Grok lanes`)
applies to the whole round; engine-only overrides use `claude-opus-5-5`, `gpt-6.1-sol`,
or `grok-4.6` at `medium`.

Add `reviewer-security` when requested or when scope touches auth, permissions,
secrets/config, shell/subprocess execution, sandboxing, network clients, dependencies,
lockfiles, CI, deserialization, or another trust boundary. Otherwise report
`Security: not run`.

For Grok calls, disable the Bash sandbox (`dangerouslyDisableSandbox: true`); keep Grok's kernel sandbox active.

## Launch

In a fresh temp directory `<tmp>`, write one neutral `<tmp>/brief.md`, identical for
every lane:

```
## Review brief
- Repo: <repo>
- Scope mode: <change review | whole-file audit>
- Target files: <exact files in scope>
- Intended behavior and review focus: <task requirements and review scope>
- Diff basis: <exact baseline or commit range; optional for whole-file audits>
- Spec source: <task, plan, or doc; otherwise derive from code and tests>
```

Keep your suspicions, proposed verdicts, and report-only or fix mode out of the brief.
Launch all selected lanes in parallel in the background:

```
plx-engine --engine <e> --mode ro --repo <repo> --prompt-file <tmp>/brief.md \
  --rubric reviewer-<dimension> --model <model> --effort <effort> \
  --out <tmp>/<e>-<dimension>.md --log <tmp>/<e>-<dimension>.log
```

If a lane fails, proceed with the others and disclose it; a missing core lane makes the
round partial.

## Synthesize and fix

Deduplicate by root cause and try to disprove each material finding against the code.
Correctness determines which objects belong in scope before cleanup or structural
remedies. Reject false positives with a reason. For change reviews, filter pre-existing
issues and untouched code without a causal link to the change. Whole-file audits may
report existing defects within the named target. In either mode, filter out-of-scope
issues, linter-only style, generic test/doc wishes, speculative unreachable cases, and
optimizations without material cost. Read further where the reports reveal a gap.

If a core lane finds a concrete security risk, run the security lane if possible or
retain the risk as a named residual. Rank confirmed findings by severity. Ask about
remedies only when intent, behavior, scope, or an interface needs a user decision;
batch those questions. For report-only requests, deliver findings and a repair plan.

After every lane has returned, apply confirmed, unambiguous remedies in one bounded fix
round, including approved answers. Fix failures your edits introduce and rerun affected
checks until they pass or a concrete blocker remains. Preserve unrelated edits. Leave
build-sized remedies and unrelated issues as residuals and recommend `/plx:build`.
Re-read your diff and run the relevant repository checks. Never `uv run` inside a
sandbox. Follow repository instructions for local commits; never publish.

## Finish

Report scope and lane coverage, confirmed and rejected findings, security status, fixes,
open decisions, residuals, and verification commands and results. Omit empty sections.
Delete `<tmp>` when done.

Request:

$ARGUMENTS
