# AI Workflow

This repository uses a local, human-in-the-loop workflow for Codex CLI and
Claude Code CLI. The harness helps collect context, generate prompts, run
optional safe checks, and write a final handoff. It does not replace the local
CLIs, and it never approves work on its own.

## Core Roles

| Role | Responsibility |
| ---- | -------------- |
| Human operator | Defines the goal, reviews artifacts, decides whether to commit or stop. |
| PowerShell harness | Collects git context, detects tests, writes prompts, enforces safety checks, and writes the handoff. |
| Codex CLI | Optional implementer, invoked only with explicit opt-in. |
| Claude Code CLI | Optional reviewer, invoked only with explicit opt-in and review-only tooling. |
| Local checks | Optional verification from trusted repository scripts; wrapper commands are checked, but script internals are not sandboxed by the harness. |

## Files To Customize First

After copying the template into a target service repo, customize:

- `AI_PRODUCT_SPEC.md` - describe the service, users, scope, and success
  criteria.
- `AI_TASK_QUEUE.md` - identify the next small task and set its status.
- `AI_ACCEPTANCE_CRITERIA.md` - adapt the review checklist to the target repo.

Do not start from real AI execution. Start with dry-run and prompt-only modes.

## Recommended Flow

1. Confirm the target repo is a git repository.
2. Validate the install with `tools/validate-template-install.ps1`.
3. Fill in `AI_PRODUCT_SPEC.md` and `AI_TASK_QUEUE.md`.
4. Run a dry-run smoke check:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -DryRun -Goal "service smoke test"
   ```

5. Read the generated `AI_FINAL_HANDOFF.md`.
6. Generate prompt-only artifacts before real AI execution:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -Implementer codex -DryRun -Goal "Codex prompt only"

   powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -Reviewer claude -DryRun -Goal "Claude review prompt only"
   ```

7. Optionally run selected opt-in local checks from trusted repositories with
   `-TestLevel unit`.
8. Only after the prompts, checks, and CLI setup are trusted, opt in to
   `-RunImplementer`, `-RunReviewer`, or `-EnableFixLoop`.
9. Review the final handoff and git diff by hand.
10. Commit or discard changes manually outside the harness.

## Capability Summary

| Capability | Default behavior | Explicit opt-in |
| ---------- | ---------------- | --------------- |
| Context collection | On for harness runs | None |
| Test detection | On for harness runs | None |
| Test execution | Off by default | `-TestLevel unit`, `integration`, `e2e`, or `all` |
| Codex prompt generation | Off by default | `-Implementer codex` |
| Codex execution | Off by default | `-Implementer codex -RunImplementer` |
| Claude prompt generation | Off by default | `-Reviewer claude` |
| Claude execution | Off by default | `-Reviewer claude -RunReviewer` |
| Bounded fix loop | Off by default | `-EnableFixLoop` with implementer and reviewer execution |

`-DryRun` suppresses test execution, Codex execution, and Claude execution even
when other execution switches are present.

## Safety Rules

The harness is designed around conservative local defaults:

- No automatic commit, push, tag, merge, or deploy.
- No dependency installation during harness runs.
- No permissive sandbox flags such as `danger-full-access`, bypass, yolo, or
  full-auto.
- No raw secret material in collected context or prompts.
- No timestamped `ai-runs/` artifacts in version control.
- No automatic approval; every run ends with a human-reviewable handoff.
- Selected local checks are trusted-repository scripts. The harness deny-lists
  wrapper command text, but it cannot guarantee script internals have no side
  effects.

If a task appears to require breaking one of these rules, stop and handle the
decision outside the harness.

## Output Artifacts

Each run writes a timestamped local folder under `ai-runs/`. Common artifacts
include:

- `AI_FINAL_HANDOFF.md` - the primary file to review last.
- `goal.txt` - the goal passed to the run.
- `git-status.txt`, `git-diff-stat.txt`, `git-diff-names.txt` - summarized git
  context.
- `detected-tests.md` and `detected-tests.json` - test detection output.
- `test-output.txt` and `test-summary.json` - test execution summary, even when
  no tests were selected.
- `codex-implementation-prompt.md` and `codex-output.md` when Codex was
  requested.
- `claude-review-prompt.md` and `claude-review.md` when Claude review was
  requested.
- `loop-summary.json` when the bounded fix loop was enabled.

Generated run folders are local artifacts. Do not commit them.

## Handoff Review

Before any commit, review:

- The goal and active task ID.
- The files changed and diff summary.
- The selected test/check commands and their results.
- Codex output, if Codex was requested.
- Claude verdict, if Claude review was requested.
- Any risks, stop reasons, or missing verification listed in the handoff.

The handoff is evidence for human judgment. It is not an approval by itself.
