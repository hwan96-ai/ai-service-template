# AI Acceptance Criteria

## Phase 1 — Harness Foundation

The harness is "done" for Phase 1 when ALL of the following are true.

### Control documents exist at repo root

- [ ] `AI_PRODUCT_SPEC.md`
- [ ] `AI_ACCEPTANCE_CRITERIA.md`
- [ ] `AI_TASK_QUEUE.md`
- [ ] `AI_WORKFLOW.md`
- [ ] `AGENTS.md`
- [ ] `CLAUDE.md`

### PowerShell tools exist under `tools/`

- [ ] `tools/ai-autopilot.ps1`
- [ ] `tools/detect-tests.ps1`
- [ ] `tools/collect-context.ps1`
- [ ] `tools/write-final-handoff.ps1`

### Run output

- [ ] Running `ai-autopilot.ps1` (with or without `-DryRun`) creates `ai-runs/<yyyyMMdd-HHmmss>/`
- [ ] The run folder contains: `goal.txt`, `git-status.txt`, `git-diff-stat.txt`, `git-diff-names.txt`, `detected-tests.md`, `detected-tests.json`, `AI_FINAL_HANDOFF.md`
- [ ] `AI_FINAL_HANDOFF.md` includes: Goal, Task ID, Run Folder, Files Changed, Git Status, Diff Summary, Detected Tests, Risks, Next Steps
- [ ] `AI_FINAL_HANDOFF.md` ends with an explicit notice that no commit, push, or deploy was performed

### Safety

- [ ] Script aborts cleanly with a clear error if not inside a git work tree
- [ ] Script aborts cleanly with a clear error if any required control doc is missing
- [ ] Script refuses `-AutoCommit` (switch) in Phase 1 with a clear message and exits before creating a run folder
- [ ] No `git commit`, `git push`, deploy, or dependency-install command is executed
- [ ] Secret-like paths (`.env`, `*.pem`, `*.key`, `*secret*`) are filtered from collected diff name lists
- [ ] No file outside the allowed list is created or modified
- [ ] `.gitignore` ignores generated `ai-runs/*` folders while preserving the tracked `ai-runs/.gitkeep` sentinel

## Phase 2 — Test Detection & Optional Execution

The harness is "done" for Phase 2 when ALL of the following are true.

### Detection

- [ ] `tools/detect-tests.ps1` emits both `detected-tests.md` and `detected-tests.json` under the run folder
- [ ] `detected-tests.json` includes `repoRoot`, `detectedStacks`, `testCommands`, `warnings`, `noTestsFound`
- [ ] Each entry in `testCommands` has `id`, `name`, `workingDirectory`, `command`, `level` (`unit|integration|e2e|typecheck|lint|build|unknown`), `safeByDefault`, `reason`
- [ ] Detection covers Node (npm/pnpm), Python (`pyproject.toml`/`pytest.ini`/`requirements.txt`/`tests/`), Playwright configs, and split repos (`frontend/`, `backend/`)
- [ ] `detect-tests.ps1` does not install dependencies and does not execute tests

### Optional execution

- [ ] `ai-autopilot.ps1 -TestLevel none` does not execute any test command (default behaviour)
- [ ] `ai-autopilot.ps1 -TestLevel unit` selects only `safeByDefault=true` commands at level `unit`/`typecheck`/`lint` and never selects E2E
- [ ] `-SkipE2E` excludes any `level=e2e` command at `-TestLevel integration`/`e2e`/`all`
- [ ] `ai-autopilot.ps1` writes both `test-output.txt` and `test-summary.json` under the run folder (even when no commands run)
- [ ] `test-summary.json` records `selectedLevel`, `skipE2E`, `dryRun`, `noCommandsSelected`, `anyFailed`, `allPassed`, and a per-command `results[]` with `id`, `command`, `workingDirectory`, `level`, `startTime`, `endTime`, `exitCode`, `passed`, `skipped`, `skipReason`
- [ ] Working directories outside the repository root are rejected before execution
- [ ] Commands matching install / destructive / git / deploy denylist patterns are rejected before execution

### Handoff

- [ ] `write-final-handoff.ps1` adds sections: Autopilot Phase, Parameters, Test Execution Summary, Test Output Location, Result, Suggested Manual Verification
- [ ] Result is `manual review required` when no tests were selected, `tests passed, manual review still required` when all selected commands passed, and `tests failed, manual review required` on any failure
- [ ] When `noTestsFound` is true, Result clearly states no automated verification was available rather than reporting success
- [ ] Final handoff still ends with the explicit `NO commit, NO push, NO deploy` notice

### Run folder uniqueness

- [ ] Run folders are stamped to millisecond precision (`yyyyMMdd-HHmmss-fff`)
- [ ] If a folder with that name already exists, a numeric suffix (`-001`, `-002`, …) is appended; existing folders are never overwritten or deleted

### Safety (carried over)

- [ ] `-AutoCommit` remains refused before any run folder is created
- [ ] No Codex CLI or Claude Code CLI is invoked in Phase 2
- [ ] No `git commit`, `git push`, `git tag`, deploy, or dependency-install command is executed
- [ ] No file outside the Phase 2 allowed list is created or modified

### Context collection robustness (Phase 2 hardening)

- [ ] `tools/collect-context.ps1` writes `git-status.txt`, `git-diff-stat.txt`, and `git-diff-names.txt` even when git emits harmless line-ending warnings (e.g. LF→CRLF notices)
- [ ] `collect-context.ps1` does not abort the harness on cosmetic native-stderr warnings
- [ ] Secret-like paths remain redacted in `git-status.txt` and `git-diff-names.txt`
- [ ] `tools/ai-autopilot.ps1` clearly logs a console warning (not silently) when any of the three context files fail to appear
- [ ] `.gitignore` ignores `.claude/` (local Claude Code CLI state) so it never appears in `git status`
- [ ] `.gitignore` continues to ignore `ai-runs/*` while preserving the `ai-runs/.gitkeep` sentinel

## Phase 3 — Claude review prompt + optional reviewer

The harness is "done" for Phase 3 when ALL of the following are true.

### Review prompt generation

- [ ] `tools/write-claude-review-prompt.ps1` exists and is invoked when `-Reviewer claude` is passed
- [ ] Running `ai-autopilot.ps1 -Reviewer claude` creates `claude-review-prompt.md` under the run folder
- [ ] `claude-review-prompt.md` includes the explicit directive `Do not edit files. Do not run commands. Review only.`
- [ ] The prompt requests a structured response with sections: Verdict, Summary, Blocking Issues, Non-blocking Issues, Test Assessment, Safety Assessment, Suggested Fix Prompt For Codex, Approval Readiness, Suggested Commit Message
- [ ] The prompt embeds only summary artifacts (`git-status.txt`, `git-diff-stat.txt`, `git-diff-names.txt`, `detected-tests.md`, `test-summary.json`, head of `test-output.txt`, optional `AI_FINAL_HANDOFF.md`) and NEVER raw file diffs or secret material

### Reviewer execution

- [ ] Without `-RunReviewer`, the harness does NOT spawn the Claude CLI process
- [ ] Without `-RunReviewer`, `claude-review.md` contains the placeholder `Claude review was requested but not executed.` and points the human at `claude-review-prompt.md`
- [ ] With `-RunReviewer`, the harness attempts the safest review-only Claude invocation pattern (`-p`, `--output-format text`, `--tools ""`) and never uses `--dangerously-skip-permissions`, `acceptEdits`, `bypassPermissions`, allowed-edit, or allowed-bash flags
- [ ] If the local Claude CLI does not accept the review-only invocation, `claude-review.md` clearly says automatic review could not be executed safely and the harness still finishes the final handoff
- [ ] No alternative permissive Claude modes are attempted as a fallback

### Handoff integration

- [ ] `write-final-handoff.ps1` adds a `## Claude Review` section listing Mode, Prompt path, Output path, Status, and Verdict
- [ ] When `claude-review.md` exists, the handoff includes either its full content or a clearly truncated preview pointing at the file
- [ ] When review was not executed, the handoff says `Claude review prompt generated but Claude was not executed.` and the Result line does NOT claim approval
- [ ] When the parsed verdict is `block`, the Result line is `Claude review verdict: block — manual review required`
- [ ] When the parsed verdict is `request_changes`, the Result line is `Claude review verdict: request changes — manual review required`
- [ ] When the parsed verdict is `approve` AND tests passed, the Result line says `Claude review approved and tests passed — manual approval still required`
- [ ] When tests failed, the Result line still reports the test failure regardless of any review verdict

### Safety (carried over)

- [ ] No Codex CLI invocation in Phase 3
- [ ] No auto-fix loop
- [ ] `-AutoCommit` remains refused before any run folder is created
- [ ] No `git commit`, `git push`, `git tag`, deploy, or dependency-install command is executed
- [ ] The reviewer path never enables file edits or shell tools through Claude
- [ ] Generated `claude-review-prompt.md` and `claude-review.md` are local `ai-runs/` artifacts and remain ignored by `.gitignore`
- [ ] Phase 1 and Phase 2 smoke tests (AutoCommit refusal, DryRun, TestLevel unit) still pass without changes to detection or context-collection scripts

## Out of Scope for Phase 3

- Codex CLI invocation
- Codex ↔ Claude fix loops
- Auto-commit, auto-push, auto-deploy

## Phase 4 — Codex one-shot implementation support

The harness is "done" for Phase 4 when ALL of the following are true.

### Codex prompt generation

- [ ] `tools/write-codex-implementation-prompt.ps1` exists and is invoked when `-Implementer codex` is passed.
- [ ] Running `ai-autopilot.ps1 -Implementer codex` creates `codex-implementation-prompt.md` under the run folder.
- [ ] `codex-implementation-prompt.md` instructs Codex to act as implementer only, make the smallest safe change for the current Goal or TaskId, follow `AGENTS.md` / `AI_ACCEPTANCE_CRITERIA.md` / `AI_TASK_QUEUE.md` / `AI_WORKFLOW.md`, and stop and report on ambiguity.
- [ ] The prompt forbids commit, push, deploy, dependency installation, broad refactors, secret access, files outside the task scope, and any permissive sandbox flag (`danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, `--full-auto`, yolo, bypass).
- [ ] The prompt requests a final structured response with sections: Summary, Files Changed, Tests Run Or Not Run, Risks, Follow-up Needed.
- [ ] The prompt embeds only summary artifacts (`git-status.txt`, `git-diff-stat.txt`, `git-diff-names.txt`, `detected-tests.md`, `test-summary.json`, optional `AI_FINAL_HANDOFF.md`, heads of the control documents) and NEVER raw file diffs, full source contents, or secret material.

### Codex execution

- [ ] Without `-RunImplementer`, the harness does NOT spawn the Codex CLI process.
- [ ] Without `-RunImplementer`, `codex-output.md` contains the placeholder `Codex implementation was requested but not executed.` and points the human at `codex-implementation-prompt.md`.
- [ ] `-DryRun` never invokes Codex even if `-RunImplementer` is also set; `codex-output.md` records the suppression.
- [ ] With `-RunImplementer` (and `-DryRun` off), the harness attempts a single `codex exec --sandbox workspace-write` invocation and never retries on failure.
- [ ] The Codex invocation never uses `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, `--full-auto`, yolo, bypass, or any other permissive sandbox / approval flag.
- [ ] Codex stdout, stderr, and exit code are captured into `codex-output.md`.
- [ ] If the local Codex CLI is missing or the safe invocation fails, `codex-output.md` clearly says automatic Codex implementation could not be executed safely and the harness still finishes the final handoff. No alternative permissive Codex modes are attempted.
- [ ] After a Codex execution attempt (success or failure), the harness re-runs `tools/collect-context.ps1` so post-Codex git status / diff artifacts are present for review.
- [ ] Tests still run after the Codex attempt according to `-TestLevel` and `-SkipE2E`.

### Handoff integration

- [ ] `write-final-handoff.ps1` adds a `## Codex Implementer` section listing Mode, Prompt path, Output path, Status, and Exit code.
- [ ] Codex Status is one of `not requested`, `prompt generated but Codex CLI was not executed`, `Codex CLI was executed once in workspace-write sandbox`, or `Automatic Codex implementation failed or was unsupported`.
- [ ] When `-RunImplementer` was not set, the Result line says `manual review required (Codex prompt generated but not executed)`.
- [ ] When Codex was executed via `-RunImplementer` but failed/unsupported, the Result line says `Codex implementation failed or was not executed safely — manual review required`.
- [ ] When tests failed, the Result line still reports the test failure regardless of Codex status.
- [ ] When Codex ran, tests passed, and Claude verdict is `approve`, the Result line says `Codex ran, tests passed, Claude review approved — manual approval still required`.
- [ ] When Codex ran but no automated verification was available (`TestLevel=none`, `noCommandsSelected`, `noTestsFound`, or `DryRun`), the Result line still flags the lack of automated verification.

### Safety (carried over)

- [ ] `-AutoCommit` remains refused before any run folder is created.
- [ ] No `git commit`, `git push`, `git tag`, deploy, or dependency-install command is executed by the harness.
- [ ] No Codex ↔ Claude fix loop is implemented.
- [ ] No automatic retry loop is implemented.
- [ ] Generated `codex-implementation-prompt.md` and `codex-output.md` are local `ai-runs/` artifacts and remain ignored by `.gitignore`.
- [ ] Phase 1, Phase 2, and Phase 3 smoke tests (AutoCommit refusal, DryRun, TestLevel unit, Reviewer claude DryRun) still pass without changes to detection or context-collection scripts.

## Out of Scope for Phase 4

- Codex ↔ Claude fix loops
- Automatic retry loops
- Auto-commit, auto-push, auto-deploy
- Permissive Codex sandbox modes (`danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, `--full-auto`, yolo, bypass)
