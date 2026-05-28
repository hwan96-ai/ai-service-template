# Development Workflow

## When To Use This

Use this document when planning or performing harness changes, especially when
deciding whether to run checks, create artifacts, or touch git state.

## Default Mode

Work in planning, review, or surgical-edit mode. Prefer small documentation or
script changes that map directly to the active task and acceptance criteria.
Do not opportunistically refactor unrelated files.

## Evidence-First Work

Before changing behavior or instructions:

1. Read the required bootstrap and rule files.
2. Inspect the current worktree and relevant docs.
3. Identify the active task and allowed files.
4. Map each edit to a concrete requirement.
5. Validate with the lightest check that proves the requirement.

## Harness Workflow

The harness itself is preview-first. Dry-run and prompt-only commands generate
human-reviewable artifacts without executing Codex, Claude, tests, dependency
installs, commits, pushes, or deploys.

Real Codex and Claude execution require explicit opt-in through harness flags
and still end in human review. The harness does not approve its own work.

## Documentation Changes

When updating agent instructions:

- Keep `AGENTS.md` and `CLAUDE.md` concise.
- Put shared durable instructions under `docs/claude/`.
- Preserve useful existing guidance by moving it into shared docs or linking to
  the authoritative document.
- Do not duplicate long instruction bodies across multiple router files.
- Keep relative links valid from the file where they appear.
