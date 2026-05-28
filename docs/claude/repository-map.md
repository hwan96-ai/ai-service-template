# Repository Map

## When To Use This

Use this document before editing files, validating scope, or deciding where a
new harness instruction belongs.

## Top-Level Layout

- `README.md`, `README_KO.md`, `TEMPLATE_USAGE.md`, `QUICKSTART.md`,
  `SERVICE_ONBOARDING_CHECKLIST.md`, `CONTRIBUTING.md`, and
  `TEMPLATE_CHANGELOG.md` document template usage and release context.
- `AI_AGENT_BOOTSTRAP.md`, `AGENTS.md`, and `CLAUDE.md` are agent entrypoints.
- `template-payload/` contains downstream service control documents copied into
  target repositories.
- `tools/` contains PowerShell harness scripts.
- `tests/` contains Pester safety self-tests and helpers.
- `examples/` contains a sample final handoff artifact.
- `assets/` contains SVG documentation imagery.
- `bin/` contains PowerShell helper entrypoints.
- `ai-runs/` is reserved for generated local run artifacts. Timestamped run
  folders are not source-controlled.

## Current Technology Evidence

The repository is PowerShell-first. Harness scripts use `.ps1` files under
`tools/` and `bin/`, and the observed test suite is Pester-based under `tests/`.
No root `package.json`, lockfile, `requirements.txt`, `pyproject.toml`,
`Dockerfile`, or `docker-compose.yml` is part of the current repository file
list.

## Editing Boundaries

For agent-harness documentation work, prefer the router files at the root and
shared durable docs under `docs/claude/`. Do not put new files under `.claude/`
for this documentation structure.

When a task provides an allow-list, edit only files in that allow-list. If a
needed file is outside scope, stop and ask for the allow-list to be expanded.
