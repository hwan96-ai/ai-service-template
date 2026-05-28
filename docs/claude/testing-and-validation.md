# Testing And Validation

## When To Use This

Use this document when selecting validation commands, reporting test evidence,
or deciding whether a documentation-only change has been checked enough.

## Available Test Evidence

The current repository evidence shows Pester safety self-tests under `tests/`
and PowerShell detection logic in `tools/detect-tests.ps1`. The tests are
designed to avoid dependency installation and avoid invoking Codex CLI or
Claude Code CLI.

## Lightweight Documentation Validation

For documentation-only changes, use lightweight checks such as:

- `git diff --check`
- `git diff --name-only` compared against the active allow-list
- Link/path review for changed Markdown files
- Targeted text searches for required safety wording

## Harness Safety Tests

If Pester is already available and the task scope justifies it, run:

```powershell
Invoke-Pester -Path .\tests\AIServiceTemplate.Safety.Tests.ps1
```

Do not install Pester or other dependencies as part of a normal agent task.

## Test Reporting

Report which checks were run, whether they passed, and what they prove. If a
check was not run because it would require dependency installation, unavailable
tools, or scope outside the task, say so directly.
