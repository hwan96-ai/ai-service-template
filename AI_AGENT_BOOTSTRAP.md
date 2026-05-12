# AI Agent Bootstrap

This is the first file any AI coding agent should read after this template is
installed into a service repo.

## Read Order

Read these files before proposing or making changes:

1. `AI_AGENT_BOOTSTRAP.md`
2. `AGENTS.md`
3. `AI_PRODUCT_SPEC.md`
4. `AI_TASK_QUEUE.md`
5. `AI_ACCEPTANCE_CRITERIA.md`
6. `AI_WORKFLOW.md`
7. `CLAUDE.md` if you are Claude Code

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
