# AI Agent Bootstrap

This is the first file any AI coding agent should read after this template is
installed into a service repo.

## Read Order

You do not need to read every control document before doing anything. The list
below is tiered — start with the required reads, then pull in the reference
docs as the task demands.

**Required first (every session):**

1. `README.md` — what this harness is and what its smallest useful workflow looks like.
2. `AI_AGENT_BOOTSTRAP.md` — this file.

**Agent rules (read the one that applies to you, then read ALL linked rule files it points to):**

- `AGENTS.md` if you are Codex CLI.
- `CLAUDE.md` if you are Claude Code.

Both entrypoints are thin indices. You MUST read every file under
`.claude/rules/` before acting:

1. `.claude/rules/start-here.md` — required reads and entry point.
2. `.claude/rules/operating-mode.md` — default mode and hard prohibitions.
3. `.claude/rules/editing-rules.md` — surgical-edit discipline.
4. `.claude/rules/escape-hatch.md` — what to do on conflict.

Reading only the index file is insufficient. Skipping any linked rule
is a safety regression.

**Reference as needed (read when the task actually requires it):**

These are downstream-service context files, not core harness docs. They live at
the repo root.

- `AI_PRODUCT_SPEC.md` — service context, scope, out-of-scope areas.
- `AI_TASK_QUEUE.md` — active task and allow-list.
- `AI_ACCEPTANCE_CRITERIA.md` — completion and safety criteria.
- `AI_WORKFLOW.md` — full workflow detail.

If the active task is a dry-run, preview, or prompt-only run, the required
reads plus your agent rules file are usually enough. Pull in the reference docs
before proposing real edits.

## Default Rules

- Do not commit, push, tag, deploy, merge, release, or install dependencies.
- Do not read, print, summarize, copy, or move secrets.
- Do not edit files outside the active task allow-list.
- Prefer dry-run or prompt-only first.
- Human approval is required before runtime implementation.
- Stop and ask if scope, acceptance criteria, or allowed files are unclear.
- Use the smallest safe change that satisfies the task.
- Do not opportunistically refactor.
- Generated `ai-runs/` artifacts are local-only and must not be committed.

## Working Pattern

Identify the active task, confirm the allowed files, map changes to acceptance
criteria, make only the necessary edits, and report validation results clearly.
If a request conflicts with these rules, stop and explain the conflict.
