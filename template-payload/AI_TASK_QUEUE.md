# AI Task Queue

Use this file to choose the next unit of work for the harness. Keep tasks small,
specific, and reviewable. The harness does not edit this queue automatically;
update statuses by hand as work moves forward.

## How To Use This Queue

1. Add one row per task.
2. Give each task a stable ID such as `T-101`.
3. Keep exactly one task in `doing` when you want the harness to focus on it.
4. Put acceptance notes in the `Notes` column or link to
   `AI_ACCEPTANCE_CRITERIA.md`.
5. Move finished work to `done` only after human review.

## Status Legend

- `ready` - ready to start
- `doing` - active task for the next harness run
- `blocked` - waiting on a decision, missing context, or failed validation
- `review` - implementation or prompt output exists and needs human review
- `done` - completed and verified by a human
- `cancelled` - no longer planned

## Queue Template

Replace these example rows after copying the template into a service repo.

| ID    | Title                                      | Status | Notes |
| ----- | ------------------------------------------ | ------ | ----- |
| T-101 | Run the first dry-run smoke check          | ready  | Use `-DryRun`; read `AI_FINAL_HANDOFF.md`; no Codex or Claude execution. |
| T-102 | Generate a Codex prompt for a small change | ready  | Use `-Implementer codex -DryRun`; review the prompt before real execution. |
| T-103 | Generate a Claude review prompt            | ready  | Use `-Reviewer claude -DryRun`; review prompt contents before real execution. |

## Active Task Notes

When a task is moved to `doing`, capture any extra constraints here.

- Active task ID: `<T-101>`
- Allowed files or directories: `<paths>`
- Validation command preference: `<dry run, unit, lint, typecheck, or manual>`
- Known risks: `<risk notes>`
