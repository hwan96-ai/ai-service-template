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

## Out of Scope for Phase 1

- Codex CLI invocation
- Claude Code CLI review invocation
- Test execution
- Auto-fix loops
- Auto-commit, auto-push, auto-deploy
