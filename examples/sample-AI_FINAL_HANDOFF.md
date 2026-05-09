# Sample AI_FINAL_HANDOFF

This is a sanitized example. It is not real run output and does not contain private paths, secrets, tokens, user names, machine names, or repository-specific data.

## Goal

Run a safe smoke check for a service repository and produce reviewable local artifacts before enabling any real AI execution.

## Mode Used

- Harness mode: dry run
- Implementer: none
- Reviewer: none
- Test level: none
- AI execution: not executed
- Run folder: `ai-runs/20260101-120000-000/`

## Files Inspected Or Changed

Inspected summary context:

- `AI_PRODUCT_SPEC.md`
- `AI_ACCEPTANCE_CRITERIA.md`
- `AI_TASK_QUEUE.md`
- `AI_WORKFLOW.md`
- `AGENTS.md`
- `CLAUDE.md`
- Git status summary
- Git diff summary
- Test detection summary

Files changed by the harness:

- None outside the local run artifact folder.

Local artifacts produced:

- `ai-runs/20260101-120000-000/goal.txt`
- `ai-runs/20260101-120000-000/git-status.txt`
- `ai-runs/20260101-120000-000/git-diff-stat.txt`
- `ai-runs/20260101-120000-000/git-diff-names.txt`
- `ai-runs/20260101-120000-000/detected-tests.md`
- `ai-runs/20260101-120000-000/detected-tests.json`
- `ai-runs/20260101-120000-000/test-output.txt`
- `ai-runs/20260101-120000-000/test-summary.json`
- `ai-runs/20260101-120000-000/AI_FINAL_HANDOFF.md`

## Safety Constraints Respected

- No secret-like file contents were read or printed.
- No files outside the local run artifact folder were modified.
- No dependency installation command was executed.
- No deploy command was executed.
- No git commit, git push, git tag, or merge command was executed.
- No permissive sandbox flags were used.
- Codex CLI was not invoked.
- Claude Code CLI was not invoked.
- Human review is required before any next step.

## Tests And Checks Detected

Detected examples:

- `npm test` from `package.json` scripts
- `npm run lint` from `package.json` scripts
- `pytest` from `tests/`

Selection summary:

- Selected test level: none
- Commands executed: 0
- E2E commands skipped: yes

## Test And Check Result Summary

No tests or checks were executed because this was a dry run with `-TestLevel none`.

Result: manual review required. This should not be treated as a passing verification run.

## AI Output Or Review Summary

Codex output: not requested.

Claude review: not requested.

Prompt artifacts: not generated in this dry-run smoke example.

## What The Human Should Review

- Confirm the goal text matches the intended task.
- Confirm detected local checks are trusted, expected, and acceptable to run locally.
- Confirm the git status and diff summary do not include unrelated changes.
- Confirm no secret-like paths appear in the collected summaries.
- Confirm the next run should remain prompt-only or should explicitly opt in to real Codex or Claude execution.

## Recommended Next Action

If the smoke check looks correct, run one of these prompt-only commands next:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -Implementer codex -DryRun -Goal "Generate a Codex implementation prompt only"

powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -Reviewer claude -DryRun -Goal "Generate a Claude review prompt only"
```

Only use real execution flags after reviewing the generated prompts and confirming the local CLIs are installed and authenticated.

## Final Safety Notice

Nothing was committed.

Nothing was pushed.

Nothing was deployed.

Nothing was installed.
