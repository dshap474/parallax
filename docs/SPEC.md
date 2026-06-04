# Polyphony — Package Specification

**Status:** draft v0.1 · **Date:** 2026-06-03 · **Author:** Daniel Shapiro

> *Polyphony* (n.): many independent voices played together into one composition.
> A Claude Code plugin that runs a build pipeline across **multiple models** — Claude
> orchestrates and writes, while Codex and Grok review read-only. The thesis, proven by
> our own benchmark: **the engine that reviews matters more than the one that writes** —
> cross-model review catches real bugs single-model review misses.

---

## 1. Purpose & thesis

Polyphony packages a cross-model software-build pipeline as an installable Claude Code
plugin. One model (Claude) plans, writes, and synthesizes; other models (Codex, Grok)
act as independent read-only reviewers at every gate. The orchestrator merges their
findings and applies fixes.

**Why anyone should care (the pitch):** in our benchmark, Codex reviewing
Claude-authored code found a genuine logic bug Claude's own review missed (a
`numeric_cols.any()` truthiness bug that silently returned an empty chart). Multiple
independent models, each blind to the others, surface defects a single model rationalizes
away. Polyphony makes that workflow one `/install` away.

**Non-goals:** Polyphony is not a model router, not an MoE serving layer, and does not
host models. It orchestrates *external CLIs you already have* (`codex`, `grok`) from
inside Claude Code.

---

## 2. Concepts (glossary)

| Term | Meaning |
|---|---|
| **Role** | A slot in the pipeline: Plan, Plan-review, Code, Refine, Debug, Correctness, Fix. Engine-agnostic. |
| **Engine** | A concrete model invocation that can fill a role: `claude-orch`, `reviewer` (claude-sub), `worker` (claude-worker), `codex-ro`, `composer-ro`. |
| **Combo** | A roster mapping roles → engines. Swapping the combo swaps the whole behavior without touching pipeline logic. |
| **Pipeline** | The shared role-based stage flow (in `references/pipeline.md`), identical across combos. |
| **Panel** | A fan-out of several engines reviewing the same artifact in parallel (read-only). |
| **Orchestrator** | The Claude main loop. It is the synthesis hub: it merges plans and reviews and applies edits. |

---

## 3. What ships

- **2 skills** — `team-dev` (everyday) and `ultra-dev` (heavyweight panel).
- **2 subagents** — `reviewer` (read-only) and `worker` (write-capable), so the panel is
  self-contained and does not depend on a user's private agent registry.
- **Shared references** — the engine cookbook, pipeline, and review briefs, carried
  self-contained inside each skill (see §9 for why).
- **Pointer docs** — README, REQUIREMENTS, ARCHITECTURE, BENCHMARK, CONTRIBUTING.
- **Manifests** — `plugin.json` + a one-repo `marketplace.json`.

---

## 4. Architecture

### 4.1 The role-based pipeline (shared)

```
Plan → Plan-review → Code → Refine → Review (Debug ∥ Correctness) → Fix
```

Stages are written against **roles**, not models. Each combo's roster assigns an engine
to each role; `references/engines.md` holds the exact invocation for each engine (the
single model-swap point).

### 4.2 The orchestration model

- **Orchestrator** = the Claude main loop (`claude-orch`). It never blocks on compute it
  could parallelize; it fans out review work in one turn and synthesizes the results.
- **Writers** = Claude only (the orchestrator directly, or a fresh `worker` subagent).
- **Reviewers** = read-only, cross-model: `codex-ro` (Codex CLI), `composer-ro` (Grok
  CLI), and a fresh `reviewer` subagent (Claude). Every reviewer is fresh, neutral-context,
  and de-spawns after returning findings.

### 4.3 Combos shipped

| Combo | Skill | Plan | Code | Review | Fix | External deps |
|---|---|---|---|---|---|---|
| **ClaudeBuildCodexReview** | `team-dev` *(default)* | Claude | fresh `worker` | `codex-ro` (plan+debug+correctness) + `reviewer` (debug) | Claude direct | **codex only** |
| **TeamDev** | `team-dev` *(opt-in)* | Claude + Codex/Grok feedback | Claude direct | 6-reviewer panel (`codex-ro` + `composer-ro` × refine/debug/correctness) | Claude direct | codex + **grok** |
| **UltraDev** | `ultra-dev` | 5-model plan panel | fresh `worker` | 9-reviewer panel (3×3 incl. `reviewer`) | Claude direct | codex + **grok** |

**Packaging decision (resolved §14):** `team-dev` defaults to **ClaudeBuildCodexReview** so
first run needs only `codex`. TeamDev (grok panel) and `ultra-dev` are the optional
"add more models" Grok tier (`composer-ro` verified 2026-06-03). One v0.1.0 package — Grok
is an optional dependency, not a separate release.

---

## 5. Repo layout

```
polyphony/                          # git repo = marketplace AND plugin
├── .claude-plugin/
│   ├── plugin.json                 # plugin manifest (name → "polyphony:" namespace)
│   └── marketplace.json            # one-repo marketplace listing this plugin
├── skills/
│   ├── team-dev/
│   │   ├── SKILL.md                # default combo = ClaudeBuildCodexReview
│   │   └── references/             # engines.md, pipeline.md, briefs (self-contained)
│   └── ultra-dev/
│       ├── SKILL.md
│       └── references/             # own copy (see §9)
├── agents/
│   ├── reviewer.md                 # read-only reviewer (= claude-sub)
│   └── worker.md                   # write-capable coder (= claude-worker)
├── docs/
│   ├── ARCHITECTURE.md             # the pipeline + engine cookbook, narrative
│   ├── REQUIREMENTS.md             # codex + grok install / auth / hardening
│   ├── BENCHMARK.md                # the lollipop experiment (evidence)
│   └── CONTRIBUTING.md
├── _source/
│   └── references/                 # canonical copy; synced into each skill (§9)
├── scripts/
│   └── sync-references.sh          # mirrors _source/references → skills/*/references
├── LICENSE
└── README.md
```

> **Do NOT** nest `skills/`, `agents/`, or `hooks/` under `.claude-plugin/` — only the two
> manifests live there. (Documented gotcha.)

---

## 6. `plugin.json`

```json
{
  "name": "polyphony",
  "version": "0.1.0",
  "description": "Multi-model build pipeline for Claude Code — Claude orchestrates and writes; Codex and Grok review read-only. Cross-model review catches bugs single-model review misses.",
  "author": { "name": "Daniel Shapiro" },
  "homepage": "https://github.com/<you>/polyphony",
  "repository": "https://github.com/<you>/polyphony",
  "license": "MIT",
  "keywords": ["multi-model", "code-review", "orchestration", "codex", "grok", "subagents", "claude-code"]
}
```

`name` must be kebab-case (`^[a-z0-9]+(-[a-z0-9]+)*$`) and becomes the namespace prefix:
skills install as `/polyphony:team-dev` and `/polyphony:ultra-dev`.

---

## 7. `marketplace.json`

```json
{
  "name": "polyphony-marketplace",
  "owner": { "name": "Daniel Shapiro" },
  "description": "Polyphony — a multi-model build pipeline plugin for Claude Code.",
  "plugins": [
    {
      "name": "polyphony",
      "source": "./",
      "description": "Multi-model build pipeline: Claude writes, Codex + Grok review read-only.",
      "version": "0.1.0",
      "category": "development",
      "keywords": ["multi-model", "code-review", "orchestration"],
      "license": "MIT"
    }
  ]
}
```

`source: "./"` makes this repo both the marketplace and the plugin host (officially
supported). Install flow for users:

```
/plugin marketplace add <you>/polyphony
/plugin install polyphony@polyphony-marketplace
/reload-plugins
```

---

## 8. Skills

Both skills drop the local `_claude-only` / `DISABLED.md` staging trick — a distributed
plugin uses plain `SKILL.md`.

### 8.1 `skills/team-dev/SKILL.md` (frontmatter)

```yaml
---
name: team-dev
description: >-
  Multi-model build pipeline (everyday default). Claude plans, a fresh worker writes
  the first pass, the orchestrator refines and fixes directly, and Codex reviews
  read-only at plan-review + debug + correctness with a fresh Claude reviewer as a
  second debug lane. Use for substantial features, refactors, or rewrites — not
  one-line fixes. Needs only the `codex` CLI by default.
argument-hint: "<feature, refactor, or task to build>"
disable-model-invocation: true
user-invocable: true
---
```

Body: the ClaudeBuildCodexReview combo (default). Documents the optional TeamDev (grok
panel) combo and how to switch. References its own `references/` via prose / relative
paths.

### 8.2 `skills/ultra-dev/SKILL.md` (frontmatter)

```yaml
---
name: ultra-dev
description: >-
  Heavyweight multi-model panel. A 5-model plan panel drafts plans, the orchestrator
  synthesizes one spec, a fresh worker builds it, then a 9-reviewer panel (Claude +
  Codex + Grok across refine/debug/correctness) audits the result and the orchestrator
  applies one synthesized refactor. Most coverage, highest cost. Needs codex AND grok.
  For everyday work prefer team-dev.
argument-hint: "<feature, refactor, or task to build>"
disable-model-invocation: true
user-invocable: true
---
```

`disable-model-invocation: true` + `user-invocable: true` → manual `/polyphony:team-dev`
only, never auto-triggered.

---

## 9. Subagents & shared references

### 9.1 `agents/reviewer.md`

```yaml
---
name: reviewer
description: >-
  Read-only code reviewer. Use when a task needs an independent review lane (debug,
  correctness, or plan critique) that returns findings only and never edits. Fresh,
  neutral context; reports a structured finding list back to the caller.
model: inherit
color: cyan
tools: Read, Grep, Glob
---
```

### 9.2 `agents/worker.md`

```yaml
---
name: worker
description: >-
  Write-capable implementation worker. Use to write a first-pass implementation from a
  precise per-task spec, keeping the orchestrator's context lean and the first pass
  uncontaminated. Returns the diff/summary.
model: inherit
color: green
tools: Read, Grep, Glob, Edit, Write, Bash
---
```

(These replace the local `claude-sub`→`reviewer` and `claude-worker`→`worker-high`
mappings with self-contained definitions.)

### 9.3 Shared references — the `${CLAUDE_PLUGIN_ROOT}` problem

`${CLAUDE_PLUGIN_ROOT}` is **broken inside SKILL.md body text** (open bug #9354), so a
skill cannot reliably read one shared `references/` at the plugin root. Therefore:

- **Each skill carries its own `references/`** (robust at runtime). Skills reference them
  with prose + relative / `${CLAUDE_SKILL_DIR}` paths, which work in skill bodies.
- **DRY is kept in the source tree:** the canonical copy lives in `_source/references/`,
  and `scripts/sync-references.sh` mirrors it into `skills/*/references/` before commit.
  One source of truth; safe runtime duplication.

There is **no first-class inter-skill reference** in Claude Code — cross-references are
prose instructions telling Claude to read a file. Pointer docs (`docs/*`, READMEs) are
human-facing and link with plain markdown.

---

## 10. Engines (cookbook summary)

Full invocations live in each skill's `references/engines.md`. Summary:

| Engine | Model / tool | Shape | Notes |
|---|---|---|---|
| `claude-orch` | Claude main loop | write (direct) | the orchestrator / synthesis hub |
| `worker` | Claude subagent | write | fresh first-pass coder |
| `reviewer` | Claude subagent | read-only | fresh review lane |
| `codex-ro` | `codex` CLI, `gpt-5.5`/high | read-only | independent cross-model reviewer |
| `composer-ro` | `grok` CLI | read-only | **STUB — must be finished before grok tiers ship (§14)** |

### Headless hardening (baked into engines.md)

- **Codex:** `codex exec --ignore-user-config --sandbox read-only --skip-git-repo-check -C <repo> -m gpt-5.5 -c model_reasoning_effort=high --ephemeral -o <OUT.md> - < <PROMPT> > <log> 2>&1`. Read only the `-o` file; redirect stdout→log (banner/token noise). Never inherit the user's `danger-full-access` config.
- **Grok:** disable the orchestrator's Bash sandbox for the call (else workers silently no-op, exit 0, no file); read-only via `--permission-mode plan` / `--disallowed-tools`; verify by the output file, not stderr; never `--yolo`.
- **Verification:** run the repo's own tools via `.venv/bin/<tool>` (`pytest`, `ruff`), **never** `uv run` in a sandbox (it panics).
- **Preflight:** `command -v codex` / `command -v grok` + a one-shot model-availability probe before stage 1; fall back / skip the missing engine's lanes.

---

## 11. External requirements (the adoption gate)

Polyphony orchestrates external CLIs. `docs/REQUIREMENTS.md` must cover:

| Tier | Needs | Enables |
|---|---|---|
| **0 (default)** | `codex` CLI + auth | `team-dev` (ClaudeBuildCodexReview) — full cross-model review |
| **1** | + `grok` CLI + auth | `team-dev` TeamDev panel, `ultra-dev` |

- Install + authenticate each CLI; link their docs.
- **Caveat:** `gpt-5.3-codex` is unavailable on ChatGPT-account Codex auth → Codex runs
  as read-only `gpt-5.5` only (no writer-model risk; this is by design).
- Preflight detects what's present and degrades gracefully — a missing engine drops its
  lane, it does not crash the run.

---

## 12. Pointer documents

| Doc | Contains |
|---|---|
| `README.md` | The pitch (lead with the benchmark), 2-command quickstart, tier table, links out. |
| `docs/REQUIREMENTS.md` | codex/grok install, auth, hardening, the gpt-5.3 caveat. |
| `docs/ARCHITECTURE.md` | The role-based pipeline, the engine cookbook, how combos map roles→engines. |
| `docs/BENCHMARK.md` | The lollipop experiment: first-pass quality, the real bug Codex caught, timing. Evidence the multi-model loop pays. |
| `docs/CONTRIBUTING.md` | How to add an engine / combo / skill; the `sync-references.sh` rule. |

---

## 13. Versioning, license, security

- **Versioning:** semver in `plugin.json`. One package at **v0.1.0**; the Grok tier is an
  optional dependency *within* it, not a separate release.
- **License:** **MIT** (resolved). Confirm the review briefs derived from the private
  `panel-review` skill are clear to relicense before publishing.
- **Security:** read-only sandboxes for all reviewers; never inherit `danger-full-access`
  / `approval_policy=never`; document the grok Bash-sandbox-disable tradeoff. Dual-use
  note: this is a dev productivity tool; reviewers cannot write.

---

## 14. Resolved decisions

1. **team-dev default combo** — ✅ ClaudeBuildCodexReview (codex-only, zero-friction first
   run); TeamDev grok panel is opt-in.
2. **Grok release** — ✅ folded into the single v0.1.0 package as an **optional** tier
   (`composer-ro` verified 2026-06-03 against grok 0.2.16). Not a separate release.
3. **License** — ✅ MIT.
4. **Owner handle** — ✅ `dshap474` (manifests + homepage/repository set).
5. **Shared-refs sync** — ✅ `scripts/sync-references.sh` (edit `_source/`, then sync).

---

## 15. Build milestones

1. ✅ **Scaffold** — repo skeleton, `plugin.json`, `marketplace.json`, LICENSE, README.
2. ✅ **Skills** — `team-dev` + `ultra-dev` as plain skills; team-dev defaults to the
   no-grok combo; `_source/references` + `sync-references.sh` wired.
3. ✅ **Subagents** — `agents/reviewer.md` + `agents/worker.md`.
4. ✅ **Engines** — `composer-ro` verified (grok read-only, plan mode, writes nothing).
5. ✅ **Docs** — REQUIREMENTS, ARCHITECTURE, BENCHMARK, CONTRIBUTING.
6. ⏳ **Verify** — clean-install in a fresh Claude Code; confirm `/polyphony:team-dev` runs
   on a codex-only machine; confirm namespacing and `/agents` registration.
7. ⏳ **Publish** — tag v0.1.0, push, smoke-test the marketplace-add + install path
   (only on explicit `$github-*` invocation).

---

## 16. Acceptance criteria (v0.1)

- [ ] `/plugin marketplace add` + `/plugin install polyphony@polyphony-marketplace` succeeds on a clean machine.
- [ ] `/polyphony:team-dev` completes a real task using only the `codex` CLI (no grok).
- [ ] The two subagents appear in `/agents` as `polyphony:reviewer` / `polyphony:worker`.
- [ ] Skills read their `references/` correctly at runtime (no `${CLAUDE_PLUGIN_ROOT}` breakage).
- [ ] Preflight degrades gracefully when an engine is absent.
- [ ] README, REQUIREMENTS, ARCHITECTURE, BENCHMARK present; LICENSE set.
</content>
</invoke>
