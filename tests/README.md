# Test environment

The default suite is deterministic and model-free:

```bash
bash tests/run.sh
```

It runs dual-package static integrity checks, then exercises the same packaged runtime
tests once from `plugins/claude/plx` and once from `plugins/codex/plx` using fake engine
executables and throwaway Git repositories. Finally it runs the vendored Python client's
unit and fake-server transport tests, explicitly excluding authenticated integration tests.
The client lane requires `uv`, installs the existing frozen lock into a disposable external
virtual environment, and fails if setup is unavailable. Its first run may download locked
dependencies; no model credentials are required. It leaves no environment or pytest cache
in the repository. Run that lane alone with `bash tests/client.sh`.

Useful commands:

```bash
tests/explain-skill.sh claude dev
tests/explain-skill.sh codex dev
PLX_PACKAGE=claude tests/smoke-scripts.sh
PLX_PACKAGE=codex tests/smoke-scripts.sh
bash tests/run.sh --with-engines
```

`--with-engines` performs small real authentication/model probes and is intentionally
off by default. `tests/smoke/` contains the larger behavioral suite and should be run
deliberately because it spends model tokens.
