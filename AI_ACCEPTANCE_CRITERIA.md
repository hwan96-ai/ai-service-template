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

## Out of Scope for Phase 2

- Codex CLI invocation
- Claude Code CLI review invocation
- Auto-fix loops
- Auto-commit, auto-push, auto-deploy
