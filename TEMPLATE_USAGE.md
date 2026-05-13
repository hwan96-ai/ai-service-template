# Template Usage

This is the practical guide for using the local safety harness in a real
service repository. The harness wraps Codex CLI and Claude Code CLI with
PowerShell scripts, conservative defaults, prompt generation, optional local
checks, and a final handoff for human review.

## You Don't Need To Read Everything First

You do not need to understand every control document before your first preview
run. Treat this guide as a reference, not a checklist. The minimum first-run
path is short:

1. Read the `README.md` opening (what this is, who it's for).
2. Skim `AI_AGENT_BOOTSTRAP.md` so you know the default rules.
3. Run a dry-run / preview command (see "Common Commands" below).
4. Open the timestamped folder under `ai-runs/` and inspect
   `AI_FINAL_HANDOFF.md` before applying anything or opting in to real AI
   execution.

The other control documents (`AI_PRODUCT_SPEC.md`, `AI_TASK_QUEUE.md`,
`AI_ACCEPTANCE_CRITERIA.md`, `AI_WORKFLOW.md`) are worth filling in when you
move past dry-run, but they are not gating prerequisites for your first preview.
This is a personal safety harness, not a corporate onboarding process.

## When To Read This

Read this after the README if you want to:

- copy the template into a target service repo,
- customize the control documents,
- run the first dry-run smoke check,
- generate prompt-only Codex or Claude artifacts,
- opt in to real local CLI execution safely.

## What You Customize After Copying

Customize these files in the target service repo before real work:

- `AI_PRODUCT_SPEC.md` - describe the service, users, scope, out-of-scope
  areas, success criteria, and important runtime constraints.
- `AI_TASK_QUEUE.md` - add one or more small tasks and mark the active task.
- `AI_ACCEPTANCE_CRITERIA.md` - adapt the checklist to the target repo while
  keeping the safety gates intact.

Usually leave these files unchanged at first:

- `tools/*.ps1` - the harness implementation.
- `AGENTS.md` and `CLAUDE.md` - default guardrails for Codex and Claude.
- `TEMPLATE_MANIFEST.json` - the copy and validation manifest.

## Copy Into A Service Repo

From the template repo, preview first:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\copy-template-to-service.ps1 `
    -TargetRepo D:\path\to\your-service-repo
```

Apply only after the preview looks correct:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\copy-template-to-service.ps1 `
    -TargetRepo D:\path\to\your-service-repo -Apply
```

Optionally append local ignore rules for generated artifacts:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\copy-template-to-service.ps1 `
    -TargetRepo D:\path\to\your-service-repo -Apply -IncludeLocalGitignoreRules
```

The copy script does not copy `.git/`, `.claude/`, or timestamped `ai-runs/`
folders. It does not delete files. It does not run git operations or dependency
installers.

Existing service `README.md` files are preserved by default. If the target
already has a README, preview shows `[skip-existing-readme] README.md`; pass
`-OverwriteReadme` only when you intentionally want to replace it with the
template README.

## Validate The Install

From the target repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate-template-install.ps1 -TargetRepo .
```

Optional dry-run smoke validation:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate-template-install.ps1 -TargetRepo . -RunSmoke
```

`-RunSmoke` uses dry-run mode. It does not invoke Codex, invoke Claude, execute
tests, install dependencies, commit, push, or deploy.

`-RunSmoke` does create local `ai-runs/<timestamp>/` artifacts in the target
repo. It does not modify source files.

## Recommended Progression

Move down this list one step at a time. Stop at the first confusing result and
read `AI_FINAL_HANDOFF.md`.

| Order | Command shape | What it does |
| ----- | ------------- | ------------ |
| 1 | `-DryRun -Goal "..."` | Collect context, detect tests, write handoff. No tests. No Codex. No Claude. |
| 2 | `-TestLevel unit -Goal "..."` | Run selected opt-in local checks from trusted repositories. No Codex. No Claude. |
| 3 | `-Implementer codex -DryRun -Goal "..."` | Generate a Codex prompt without running Codex. |
| 4 | `-Reviewer claude -DryRun -Goal "..."` | Generate a Claude review prompt without running Claude. |
| 5 | `-Implementer codex -RunImplementer -TestLevel unit -Goal "..."` | Run one Codex implementation attempt, then selected checks. |
| 6 | `-Reviewer claude -RunReviewer -TestLevel unit -Goal "..."` | Run Claude review-only mode, then selected checks. |
| 7 | `-Implementer codex -RunImplementer -Reviewer claude -RunReviewer -TestLevel unit -Goal "..."` | Run one Codex attempt plus Claude review. |
| 8 | Add `-EnableFixLoop -MaxIterations 2` | Allow a bounded fix loop after the one-shot path is trusted. |

Do not start with the bounded fix loop. Use it only after the one-shot
implementer and reviewer paths are understood for the target repo.

## Common Commands

Dry-run smoke check:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -DryRun -Goal "service smoke test"
```

Selected local checks:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -TestLevel unit -Goal "unit validation"
```

Codex prompt-only mode:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Implementer codex -DryRun -Goal "Generate a Codex implementation prompt only"
```

Claude prompt-only mode:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Reviewer claude -DryRun -Goal "Generate a Claude review prompt only"
```

One-shot Codex execution:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Implementer codex -RunImplementer -TestLevel unit -Goal "one-shot implementation"
```

Claude review-only execution:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Reviewer claude -RunReviewer -TestLevel unit -Goal "review current changes"
```

Bounded fix loop:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Implementer codex -RunImplementer `
    -Reviewer claude -RunReviewer `
    -EnableFixLoop -MaxIterations 2 -TestLevel unit -Goal "bounded fix loop"
```

## Run Artifacts

Each harness run writes a timestamped folder under `ai-runs/`.

Review these files first:

- `AI_FINAL_HANDOFF.md`
- `test-summary.json`
- `test-output.txt`
- `codex-output.md`, when Codex was requested
- `claude-review.md`, when Claude was requested
- `loop-summary.json`, when the bounded fix loop was enabled

Do not commit timestamped `ai-runs/` folders. Keep only `ai-runs/.gitkeep`.

## Safety Model

The harness never performs these actions on its own:

- commit, push, tag, merge, or deploy,
- dependency installation,
- destructive cleanup,
- permissive Codex sandbox modes,
- Claude file-edit or shell-command tool grants,
- automatic approval.

`-DryRun` always suppresses Codex execution, Claude execution, and test
execution. Generated prompts and handoffs are for human review.

For selected local checks, the harness deny-lists unsafe wrapper command text.
It cannot guarantee that trusted repository test scripts do not perform side
effects internally.

## Troubleshooting

### Claude CLI rejects the review-only flags

The harness records that automatic Claude review could not be executed safely
and continues to the final handoff. Do not switch to permissive Claude flags.
Use the generated `claude-review-prompt.md` manually if needed.

### Codex CLI rejects the workspace-write sandbox

The harness records that automatic Codex implementation failed or was
unsupported. Do not switch to permissive Codex sandbox flags. Use the generated
`codex-implementation-prompt.md` manually if needed.

### No tests are found

The handoff reports that automated verification was unavailable. That is not a
success result. Add or document selected local checks from trusted repositories
before relying on automated verification.

### Diff or changed-file caps are exceeded

The bounded fix loop halts when the diff grows beyond configured caps. Narrow
the task or review the diff by hand before raising limits.

### PowerShell blocks script execution

Use the per-invocation pattern shown in the examples:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 ...
```

This does not change the machine-wide execution policy.
