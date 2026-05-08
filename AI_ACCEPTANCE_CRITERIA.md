# AI Acceptance Criteria

Use this file as the review checklist for the harness after it has been copied
into a target service repo. Customize service-specific criteria as needed, but
do not loosen the safety requirements without an explicit human decision.

## Target Repo Setup

- [ ] The target repo is a git repository.
- [ ] Required control documents are present:
  - [ ] `AI_PRODUCT_SPEC.md`
  - [ ] `AI_ACCEPTANCE_CRITERIA.md`
  - [ ] `AI_TASK_QUEUE.md`
  - [ ] `AI_WORKFLOW.md`
  - [ ] `AGENTS.md`
  - [ ] `CLAUDE.md`
- [ ] Required tool scripts are present under `tools/`.
- [ ] `ai-runs/.gitkeep` exists.
- [ ] `.gitignore` ignores timestamped `ai-runs/` folders and `.claude/`.
- [ ] `tools/validate-template-install.ps1 -TargetRepo .` passes, or any
  warnings are understood and accepted.

## Product Context Quality

- [ ] `AI_PRODUCT_SPEC.md` describes the service, users, scope, out-of-scope
  areas, success criteria, and verification approach.
- [ ] `AI_TASK_QUEUE.md` has one clear active task or a clear next task.
- [ ] The active task is small enough for a single reviewable change.
- [ ] The allowed files or directories are clear.
- [ ] Open questions are documented before real AI execution.

## Dry-Run And Prompt-Only Readiness

- [ ] A dry-run smoke check completes:

  ```powershell
  powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -DryRun -Goal "service smoke test"
  ```

- [ ] The run creates a timestamped folder under `ai-runs/`.
- [ ] The run writes `AI_FINAL_HANDOFF.md`.
- [ ] The handoff clearly reports that no Codex execution, Claude execution,
  tests, dependency installation, commit, push, or deploy occurred.
- [ ] Prompt-only Codex mode can generate a prompt without running Codex.
- [ ] Prompt-only Claude review mode can generate a prompt without running
  Claude.

## Test Detection And Optional Checks

- [ ] Test detection produces human-readable and structured output.
- [ ] Detected commands have a working directory, command text, level, safety
  flag, and reason.
- [ ] Commands outside the repo are rejected.
- [ ] Install, destructive, git, and deploy commands are rejected by policy.
- [ ] `-TestLevel none` runs no tests.
- [ ] `-TestLevel unit` selects only conservative unit, lint, or typecheck
  commands.
- [ ] If no tests are available, the handoff reports that automated
  verification was unavailable rather than treating the run as successful.

## Implementer Criteria

- [ ] Codex CLI is never invoked unless `-Implementer codex -RunImplementer`
  is provided and `-DryRun` is absent.
- [ ] Codex runs use only `codex exec --sandbox workspace-write`.
- [ ] No permissive sandbox or approval-bypass flags are used.
- [ ] Codex output, stderr, and exit code are captured in the run folder.
- [ ] If Codex execution fails or is unsupported, the handoff says so clearly
  and still requires human review.
- [ ] Codex prompts contain summary context only, not raw secret material.

## Reviewer Criteria

- [ ] Claude Code CLI is never invoked unless `-Reviewer claude -RunReviewer`
  is provided and `-DryRun` is absent.
- [ ] Claude review uses print/review-only mode with tools disabled.
- [ ] Claude is not granted file-edit or shell-command tools by the harness.
- [ ] Claude output is captured in the run folder.
- [ ] If Claude execution fails or is unsupported, the handoff says so clearly
  and still requires human review.
- [ ] Review verdicts never override failing tests or safety stops.

## Bounded Fix Loop Criteria

- [ ] The fix loop is off by default.
- [ ] The loop only runs when explicitly enabled with implementer execution.
- [ ] The iteration count is capped at `3`.
- [ ] Diff-size and changed-file caps remain active.
- [ ] Secret-like paths, repeated failures, blocking review verdicts, or
  unsupported Codex execution halt the loop.
- [ ] Additional iterations use fix-only prompts with limited summary context.
- [ ] The final handoff reports the terminal action and reason.

## Handoff Criteria

- [ ] Every run ends with `AI_FINAL_HANDOFF.md`.
- [ ] The handoff includes the goal, parameters, run folder, git summary,
  detected tests, test summary, implementer status, reviewer status, risks,
  and recommended next action.
- [ ] The handoff states that human approval is still required.
- [ ] The handoff explicitly states that nothing was committed, pushed,
  deployed, or installed by the harness.

## Release Hygiene

- [ ] No timestamped `ai-runs/` folders are tracked.
- [ ] No `.claude/` local state is tracked.
- [ ] No secret-like files are tracked or summarized.
- [ ] Documentation describes current capabilities rather than internal build
  history.
- [ ] Public docs explain what users customize after copying into a target
  service repo.
