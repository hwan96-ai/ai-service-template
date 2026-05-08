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

## Phase 5 — Bounded Codex ↔ Claude fix loop

The harness is "done" for Phase 5 when ALL of the following are true.

### Defaults and refusals

- [ ] `-EnableFixLoop` defaults to **off**. With Phase 5 flags absent, `ai-autopilot.ps1` runs exactly one iteration and produces the same artifacts as Phase 4 plus per-iteration snapshots.
- [ ] `-Implementer none`, `-RunImplementer:$false`, `-Reviewer none`, `-RunReviewer:$false`, and `-MaxIterations 1` remain the defaults.
- [ ] `-FixTrigger` accepts only `tests`, `claude`, or `tests-or-claude`. The default value is `tests-or-claude`. Older values such as `review` or `both` are no longer accepted.
- [ ] `-MaxChangedFiles` defaults to `12` (conservative). `-MaxDiffStatLines` defaults to `120` (conservative). Users may override these per-invocation but the template defaults must not be silently widened.
- [ ] `-MaxIterations` is hard-capped at `3`. `-MaxIterations 0`, `-MaxIterations 4`, etc. abort cleanly **before** any run folder is created and **before** any Codex / Claude process is spawned.
- [ ] `-AutoCommit` remains refused before any run folder is created.
- [ ] `-DryRun` continues to suppress Codex execution, Claude execution, and test execution even when `-EnableFixLoop`, `-RunImplementer`, or `-RunReviewer` are also set.

### Fix prompt generation

- [ ] `tools/write-codex-fix-prompt.ps1` exists and is invoked for iterations 2+ when `-Implementer codex -EnableFixLoop` is set.
- [ ] The fix prompt instructs Codex to act as a fix-only implementer and forbids broadening scope, dependency installation, commit / push / deploy / tag, secret access, destructive shell commands, and any permissive sandbox / approval flag.
- [ ] The fix prompt embeds only failed-test summaries from the previous iteration's `test-summary.json`, the parsed Claude `Verdict` / `Blocking Issues` / `Non-blocking Issues` / `Suggested Fix Prompt For Codex` excerpt, and the filtered git status / diff stat / diff names. It NEVER embeds raw file diffs, full source contents, or secret material.
- [ ] The fix prompt requests a structured response with sections: Summary, Files Changed, Tests Run Or Not Run, Risks, Follow-up Needed.

### Iteration execution

- [ ] Iteration 1 always uses the Phase 4 implementation prompt produced by `tools/write-codex-implementation-prompt.ps1`.
- [ ] Iterations 2+ use the fix prompt produced by `tools/write-codex-fix-prompt.ps1`.
- [ ] The Codex invocation pattern stays locked to `codex exec --sandbox workspace-write <prompt>` for every iteration. The harness never uses `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, `--full-auto`, yolo, bypass, or any other permissive sandbox / approval flag.
- [ ] The Claude invocation pattern stays locked to `claude -p <prompt> --output-format text --tools ""`. The harness never enables file edits or shell tools through Claude.
- [ ] After each iteration, the harness re-runs `tools/collect-context.ps1` so the next iteration's safety checks reflect post-Codex state.
- [ ] Iterations 2+ are not invoked when iteration 1's Codex did not actually execute (Codex `prompt-only`, `not-requested`, or `failed-or-unsupported`).

### Stop conditions

The loop must halt or stop on every one of the following:

- [ ] Claude verdict `approve` → terminal action `stop`, reason `claude-verdict-approve`.
- [ ] Claude verdict `block` → terminal action `halt`, reason `claude-verdict-block`.
- [ ] Iteration budget exhausted → terminal action `stop`, reason `iteration-budget-exhausted`.
- [ ] `-EnableFixLoop` is off → terminal action `stop`, reason `fix-loop-disabled`.
- [ ] Cumulative changed-file count > `-MaxChangedFiles` → terminal action `halt`, reason starts with `max-changed-files-exceeded`.
- [ ] Cumulative diff insertions+deletions > `-MaxDiffStatLines` → terminal action `halt`, reason starts with `max-diff-stat-exceeded`.
- [ ] Secret-like paths appear in `git-diff-names.txt` (either explicit secret-shaped names or the redaction marker emitted by `collect-context.ps1`) → terminal action `halt`, reason `secret-like-paths-in-diff`.
- [ ] The same failure fingerprint repeats across consecutive iterations → terminal action `halt`, reason `repeated-failure-fingerprint`.
- [ ] Codex executed but failed or was unsupported → terminal action `halt`, reason `codex-failed-or-unsupported`.
- [ ] No Claude verdict detected AND no fixable test failure → terminal action `stop`, reason `no-claude-verdict-and-no-fixable-failure` or `claude-review-not-executed-no-fixable-failure`.
- [ ] Codex never executed in iteration 1 → terminal action `stop`, reason `no-codex-execution-cannot-fix`.
- [ ] "No tests found", "no commands selected", and "Claude review not executed" are never treated as success.

### Iteration artifacts

- [ ] Each iteration writes `iteration-XX-summary.md` and `iteration-XX-decision.json`.
- [ ] When applicable, each iteration also writes `iteration-XX-codex-implementation-prompt.md` (iteration 1) or `iteration-XX-codex-fix-prompt.md` (iterations 2+), `iteration-XX-codex-output.md`, `iteration-XX-test-summary.json`, `iteration-XX-test-output.txt`, `iteration-XX-claude-review-prompt.md`, and `iteration-XX-claude-review.md`.
- [ ] The harness writes a top-level `loop-summary.json` recording every iteration's `codexStatus`, `testsAnyFailed`, `testsAllPassed`, `reviewVerdict`, `action`, `reason`, and `fingerprint`.
- [ ] Existing top-level files (`codex-implementation-prompt.md`, `codex-fix-prompt.md`, `codex-output.md`, `test-summary.json`, `test-output.txt`, `claude-review-prompt.md`, `claude-review.md`) are preserved as the latest iteration's snapshot for Phase 2/3/4 readers and `write-final-handoff.ps1`.

### Handoff integration

- [ ] `write-final-handoff.ps1` adds a `## Loop Summary` section with EnableFixLoop, FixTrigger, MaxIterations, CompletedIterations, TerminalAction, TerminalReason, MaxChangedFiles, MaxDiffStatLines, and a per-iteration table.
- [ ] When the loop converges across multiple iterations (Codex executed, tests passed, Claude verdict `approve`, `CompletedIterations > 1`), the Result line says `Codex ↔ Claude fix loop converged after N iterations: tests passed, Claude review approved — manual approval still required`.
- [ ] When the loop halts on a Phase 5 safety check (secret-like paths, MaxChangedFiles, MaxDiffStatLines, repeated-failure-fingerprint), the Result line says `fix loop halted by Phase 5 safety check (<reason>) — manual review required`.
- [ ] When tests failed in the final iteration, the Result line still reports the test failure regardless of the loop state.
- [ ] When `-EnableFixLoop` is off, the Result line falls back to the existing Phase 2 / 3 / 4 wording.

### Safety (carried over)

- [ ] No `git commit`, `git push`, `git tag`, deploy, or dependency-install command is executed by the harness in any iteration.
- [ ] No iteration introduces permissive sandbox / approval flags (`danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, `--full-auto`, yolo, bypass).
- [ ] No iteration broadens the allowed-files scope; the fix prompt explicitly forbids unrelated refactors.
- [ ] Generated `iteration-XX-*`, `loop-summary.json`, `codex-fix-prompt.md`, etc. are local `ai-runs/` artifacts and remain ignored by `.gitignore`.
- [ ] Phase 1, Phase 2, Phase 3, and Phase 4 smoke tests (AutoCommit refusal, DryRun, TestLevel unit, Reviewer claude DryRun, Implementer codex DryRun) still pass without changes to detection or context-collection scripts.
- [ ] No file outside the Phase 5 allowed list is created or modified by the harness implementation itself.

## Out of Scope for Phase 5

- Iteration counts greater than `3`.
- Auto-commit, auto-push, auto-deploy, auto-tag, auto-merge.
- Dependency installation.
- Permissive Codex sandbox modes.
- Embedding raw source diffs or secret material in the fix prompt.
