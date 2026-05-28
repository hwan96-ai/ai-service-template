# Release And Git Hygiene

## When To Use This

Use this document before staging, committing, pushing, tagging, releasing, or
summarizing git status for harness work.

## Normal Harness Policy

The harness is designed around human-controlled git actions. Its scripts and
documentation state that the harness does not automatically commit, push, tag,
merge, deploy, release, or install dependencies.

Agents should not perform those actions unless the active task explicitly asks
for them and the repository safety rules allow the action. If a task conflicts
with the safety rules, stop and report the conflict instead of silently crossing
the boundary.

## Before Staging

Run `git diff --check` and inspect `git diff --name-only`. Confirm every changed
file is inside the active task allow-list. If any forbidden file appears, stop
and report before staging.

Stage only the files required by the task. Never stage local-only task files,
timestamped `ai-runs/` folders, `.env*` files, secret-like files, or generated
local state.

## Commit And Push Reporting

When a commit or push is allowed by the active task and safety rules, report the
branch name, commit hash, push status, and final git status. Confirm whether
product code changed and whether local-only task files were excluded.
