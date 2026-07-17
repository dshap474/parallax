# Repository instructions

## Architecture and scope

- Primary entry points: `<paths>`
- Important package boundaries: `<boundaries>`
- Generated or vendored paths: `<paths>`

## Commands

- Environment setup: `<command>`
- Focused tests: `<command>`
- Full tests: `<command>`
- Static checks: `<command>`
- Regeneration: `<command or not applicable>`

## Change policy

- Keep changes scoped to the requested behavior.
- Preserve unrelated working-tree changes.
- Do not reformat unrelated files.
- Preserve public APIs unless the task explicitly changes them.
- Do not edit generated or vendored files directly.
- Add or update tests for behavior changes.

## Definition of done

- Relevant focused tests pass.
- Relevant static checks pass.
- New behavior has regression coverage.
- Documentation is updated when public behavior changes.
