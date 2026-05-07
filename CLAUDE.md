# CLAUDE.md — Instructions for Claude Code CLI

This file is read by Claude Code CLI when invoked from this repository.

## Role in Phase 1

**Review only.** In Phase 1, Claude does not implement features. Claude may be asked to:

- read the repository
- read the latest folder under `ai-runs/`
- read the proposed diff or `AI_FINAL_HANDOFF.md`
- produce a written review

Claude does **not** commit, push, deploy, install dependencies, or run tests in Phase 1.

## Allowed file scope (when later phases enable implementation)

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

If a task appears to require editing files outside this list, **stop and surface the conflict** to the human.

## Hard rules

- No `git commit`, `git push`, `git tag`, or deploy operations.
- No dependency installation. Do not modify `package.json`, lockfiles, or CI files.
- No reading or echoing of secret material (`.env`, `*.pem`, `*.key`, anything matching `*secret*`).
- No destructive shell operations (`rm -rf`, `Remove-Item -Recurse -Force` outside the active run folder, `git reset --hard`, force pushes).
- No file modifications outside the repository root.
- No autonomous test execution in Phase 1.

## Review checklist (use when asked to review)

1. Does the change stay within the Phase 1 allowed file list?
2. Is the change traceable to a task ID in `AI_TASK_QUEUE.md`?
3. Does it satisfy the relevant entries in `AI_ACCEPTANCE_CRITERIA.md`?
4. Are any safety rules violated (commits, pushes, secrets, destructive ops)?
5. Are there unhandled error paths in the PowerShell scripts?
6. Is `AI_FINAL_HANDOFF.md` complete and accurate?

Output should be a short markdown review with: Summary, Findings (severity-tagged), Recommendations, Verdict (`approve` / `request changes` / `block`).

## Escape hatch

If the request is unsafe, ambiguous, or expands scope: emit a short structured report (task ID, concern, suggested next step) and stop. Do not proceed.
