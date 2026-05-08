# Service Onboarding Checklist

Use this checklist when adding the harness to a service repository for the first
time. It is written for a semi-technical user who wants copy-paste commands and
clear stop points.

## 1. Before Copying

- [ ] You are on a branch where adding template files is acceptable.
- [ ] The target repo is a git repository.
- [ ] You know the absolute path to the target repo.
- [ ] You have read the README quickstart.
- [ ] You understand that the copy script is preview-only unless `-Apply` is
  provided.
- [ ] You understand that the harness does not commit, push, deploy, or install
  dependencies.

## 2. Preview The Copy

From the template repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\copy-template-to-service.ps1 `
    -TargetRepo D:\path\to\your-service-repo
```

Check the printed file list. If anything looks unexpected, stop before using
`-Apply`.

## 3. Apply The Copy

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\copy-template-to-service.ps1 `
    -TargetRepo D:\path\to\your-service-repo -Apply -IncludeLocalGitignoreRules
```

Expected result:

- [ ] Control documents are present in the target repo.
- [ ] Harness scripts are present under `tools/`.
- [ ] `ai-runs/.gitkeep` exists.
- [ ] Timestamped `ai-runs/` folders and `.claude/` remain local-only.

## 4. Customize The Required Docs

Edit these before real work:

- [ ] `AI_PRODUCT_SPEC.md` - service overview, users, scope, success criteria,
  verification notes, and open questions.
- [ ] `AI_TASK_QUEUE.md` - at least one small task with a stable task ID.
- [ ] `AI_ACCEPTANCE_CRITERIA.md` - any target-specific checks that should be
  reviewed before approval.

Leave these unchanged at first:

- [ ] `tools/*.ps1`
- [ ] `TEMPLATE_MANIFEST.json`
- [ ] `AGENTS.md`
- [ ] `CLAUDE.md`

## 5. Validate The Install

From the target repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate-template-install.ps1 -TargetRepo .
```

Expected result:

- [ ] Required files pass validation.
- [ ] PowerShell scripts parse.
- [ ] Warnings, if any, are understood.

## 6. Run The First Smoke Check

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -DryRun -Goal "service smoke test"
```

Expected result:

- [ ] A new timestamped folder appears under `ai-runs/`.
- [ ] `AI_FINAL_HANDOFF.md` exists in that folder.
- [ ] No Codex CLI execution occurred.
- [ ] No Claude Code CLI execution occurred.
- [ ] No tests were executed.
- [ ] Nothing was committed, pushed, deployed, or installed.

Stop here if the handoff is missing or confusing.

## 7. Generate Prompt-Only Artifacts

Codex prompt only:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Implementer codex -DryRun -Goal "Generate a Codex implementation prompt only"
```

Claude review prompt only:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Reviewer claude -DryRun -Goal "Generate a Claude review prompt only"
```

Expected result:

- [ ] Prompt files are written under a timestamped `ai-runs/` folder.
- [ ] Codex CLI is not executed.
- [ ] Claude Code CLI is not executed.
- [ ] The prompts match the intended task and safety rules.

## 8. Optional Real CLI Verification

Only continue if the prompt-only path looks correct and the local CLIs are
installed and authenticated.

- [ ] `codex --version` works.
- [ ] `claude --version` works.
- [ ] The Codex prompt looks scoped and conservative.
- [ ] The Claude review prompt asks for review only.
- [ ] The active task in `AI_TASK_QUEUE.md` is small enough for one run.

Run one-shot Codex only when ready:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Implementer codex -RunImplementer -TestLevel unit -Goal "one-shot implementation"
```

Run Claude review-only only when ready:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Reviewer claude -RunReviewer -TestLevel unit -Goal "review current changes"
```

## 9. Before Any Human Commit

- [ ] Read `AI_FINAL_HANDOFF.md`.
- [ ] Read `git status --short`.
- [ ] Review the actual diff.
- [ ] Confirm changed files match the active task.
- [ ] Confirm tests/checks either passed or missing coverage is documented.
- [ ] Confirm no generated `ai-runs/<timestamp>/` folder is staged.
- [ ] Confirm no `.claude/` local state is staged.
- [ ] Confirm no secret-like path is staged.

The harness does not commit. A human decides what to stage and commit.

## 10. Stop Conditions

Stop and ask for help when:

- [ ] Validation fails and the missing file is not obvious.
- [ ] `AI_FINAL_HANDOFF.md` is missing.
- [ ] Codex output suggests installing dependencies, committing, pushing,
  deploying, or broadening scope.
- [ ] Claude returns a blocking verdict.
- [ ] The bounded fix loop halts on repeated failures, secret-like paths, or
  diff-size limits.
- [ ] You see changes to harness scripts that you did not intend.

Default rule: if anything is unclear, stop and read the latest
`AI_FINAL_HANDOFF.md` before continuing.
