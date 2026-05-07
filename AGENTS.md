# AGENTS.md — Instructions for Codex CLI

This file is read by Codex CLI when invoked from this repository.

## Scope

Codex may read all files in the repository. Codex may modify only files within the **allowed list** for the current phase. In Phase 1, no implementation is performed; this file exists so Codex has clear guardrails when later phases enable implementation.

## Phase 1 allowed files

```
AI_PRODUCT_SPEC.md
AI_ACCEPTANCE_CRITERIA.md
AI_TASK_QUEUE.md
AI_WORKFLOW.md
AGENTS.md
CLAUDE.md
tools/ai-autopilot.ps1
tools/detect-tests.ps1
tools/collect-context.ps1
tools/write-final-handoff.ps1
ai-runs/.gitkeep
```

If a task appears to require modifying a file outside this list, **stop and report**. Do not silently expand scope.

## Hard rules

- Do not run `git commit`, `git push`, `git tag`, or any deploy command.
- Do not install dependencies (`npm`, `pnpm`, `pip`, `poetry`, `uv`, etc.).
- Do not modify `package.json`, lockfiles, or CI configuration.
- Do not read or print secret material. Treat any match of `.env`, `*.pem`, `*.key`, or `*secret*` as off-limits.
- Do not run destructive commands (`rm -rf`, `Remove-Item -Recurse -Force` on anything outside the current run folder, `git reset --hard`, force pushes).
- Do not make network calls beyond what Codex CLI itself performs.
- Do not modify files outside the repository root.

## Workflow expectations

1. Read `AI_PRODUCT_SPEC.md`, `AI_ACCEPTANCE_CRITERIA.md`, `AI_TASK_QUEUE.md`, `AI_WORKFLOW.md` first.
2. Identify the active task by ID.
3. Propose changes that map directly to acceptance criteria.
4. Keep diffs minimal. Prefer editing existing files over creating new ones.
5. Surface uncertainty rather than guessing — output a clarifying question instead of guessing at scope.

## Escape hatch

If the requested task is unsafe, ambiguous, or out of scope: emit a short report that includes the task ID, the conflict, and a proposed safe alternative. Do not proceed.
