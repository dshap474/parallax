# Test environment

The default suite is deterministic and model-free:

```bash
bash tests/run.sh
```

It runs dual-package static integrity checks, then exercises the same packaged runtime
tests once from `plugins/claude/plx` and once from `plugins/codex/plx` using fake engine
executables and throwaway Git repositories.

Useful commands:

```bash
tests/explain-skill.sh claude dev
tests/explain-skill.sh codex dev
tests/smoke-scripts.sh claude
tests/smoke-scripts.sh codex
bash tests/run.sh --with-engines
```

`--with-engines` performs small real authentication/model probes and is intentionally
off by default. `tests/smoke/` contains the larger behavioral suite and should be run
deliberately because it spends model tokens.
