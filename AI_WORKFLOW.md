# AI Workflow

This repository uses a human-in-the-loop AI workflow. **No AI tool commits, pushes, or deploys on its own in any phase covered here.**

## Tools and roles

| Tool             | Role in this workflow                                                |
| ---------------- | -------------------------------------------------------------------- |
| ChatGPT (web)    | Planning, prompt design, breaking work into tasks                    |
| Codex CLI        | Local code implementation (later phase)                              |
| Claude Code CLI  | Local code review and controlled implementation (later phase)        |
| PowerShell tools | Local orchestration: context collection, test detection, handoff doc |
| git              | Version control. Commits are made by the human, not by tools         |
| Local tests      | Validation. Test runners are detected in Phase 1 but not executed    |

## Phase 1 — Foundation (current)

Goal: establish a safe scaffold the human can drive manually.

1. Human writes / refines `AI_PRODUCT_SPEC.md`, `AI_ACCEPTANCE_CRITERIA.md`, `AI_TASK_QUEUE.md`.
2. Human runs `tools/ai-autopilot.ps1` (typically with `-DryRun` until trusted).
3. The autopilot script:
   - verifies the repo is a git work tree
   - verifies all required control documents exist
   - creates a timestamped folder under `ai-runs/`
   - runs `tools/collect-context.ps1` (git status / diff snapshots)
   - runs `tools/detect-tests.ps1` (probes for test config files)
   - runs `tools/write-final-handoff.ps1` (produces `AI_FINAL_HANDOFF.md`)
   - prints a final notice that nothing was committed, pushed, or deployed
4. Human reads `AI_FINAL_HANDOFF.md` and decides next steps.

In Phase 1, `-DryRun` means: do **not** invoke Codex, do **not** invoke Claude, do **not** run tests, do **not** install dependencies, do **not** commit, push, deploy, or perform destructive actions. `-DryRun` does still produce the safe local report files inside the run folder so the workflow can be smoke-tested.

### Local artifacts and `.gitignore`

Generated `ai-runs/<yyyyMMdd-HHmmss>/` folders are **local run artifacts**. They must not be committed. The repo's `.gitignore` ignores `ai-runs/*` while keeping the tracked `ai-runs/.gitkeep` sentinel so a fresh clone still has the directory.

### Smoke-testing AutoCommit refusal

`-AutoCommit` is a switch and is refused in Phase 1. To verify the refusal path:

```
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -AutoCommit -Goal "AutoCommit refusal test"
```

Expected: the script writes `AutoCommit is not permitted in Phase 1. Aborting before any action.` and exits with code `2` **before** creating any run folder under `ai-runs/`.

## Phase 2 — Implementer integration (deferred)

Planned: `-Implementer codex` will hand the task description and context bundle to Codex CLI for proposing a patch. The human still reviews and commits.

## Phase 3 — Reviewer integration (deferred)

Planned: `-Reviewer claude` will run Claude Code CLI in review mode against the proposed changes and append review notes to the handoff. The human still owns commit / push / deploy.

## Phase 4 — Test execution (deferred)

Planned: respect `-TestLevel` and `-SkipE2E` to actually invoke detected test runners. Until then, those flags are only recorded in the handoff.

## Non-negotiable rules

- No tool commits, pushes, deploys, or installs dependencies automatically in any phase described here.
- No tool reads or echoes secret material (`.env`, `*.pem`, `*.key`, anything matching `*secret*`).
- All AI tools operate inside the repository directory only.
- Human approves every transition from one phase to the next.
