# PLX trace store

This directory owns the local, git-ignored SQLite trace store at `traces.db`.
It is evaluation data, not runtime state to copy into repositories PLX operates on.

## Schema v1

- `runs`: one PLX skill invocation. Stores timing, skill, host/model, task,
  routing summary, outcome, verification, final report, and optional host trace.
- `lanes`: one engine invocation within a run. Stores role, engine/model/effort,
  mode, routing reason and candidates, timing, exit code, prompt, raw trace,
  final output, evaluation, and trace SHA-256.

Grouped `runs.id` values come from the `plx-<skill>.<suffix>` temp-directory basename;
host-only and standalone runs receive generated IDs. `lanes.trace_sha256` identifies
trace content; it is not the run ID. JSON columns must contain valid JSON when present.

## Operating rules

- Keep writes short and enable foreign keys, WAL, and a busy timeout per connection.
- Treat task, prompt, trace, and output fields as sensitive local data. Never commit,
  publish, or print them wholesale without explicit user authorization.
- Preserve recorded runs. Schema changes require a migration and an increment to
  SQLite `user_version`; do not silently reinterpret existing columns.
- Capture is owned by `plx-engine` lane finalization and each skill's terminal
  `plx-eval finish` call. No hooks are configured.
