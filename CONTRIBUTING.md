# Contributing

This project is an early-stage, safety-oriented PowerShell harness for Codex CLI
and Claude Code CLI. Contributions are welcome, but changes that affect
guardrails, sandbox behavior, prompt redaction, test execution, CI, or generated
artifacts should stay small and be reviewed carefully.

## Before You Contribute

- Read `README.md` and `SECURITY.md` first.
- Keep proposed changes narrow and easy to review.
- Discuss broad automation or behavior changes before opening a large pull
  request.
- Do not add dependency installs, deploy steps, auto-commit behavior,
  permissive sandbox defaults, or broad automation without prior discussion.

## Reporting Bugs

When reporting a bug, include:

- The command you ran.
- The PowerShell version and Windows version.
- The expected behavior.
- The actual behavior.
- Any non-sensitive error output.

Do not include secrets, tokens, private repository contents, or generated local
artifacts from `ai-runs/`.

## Reporting Security/Safety Issues

Report security or safety concerns privately using the process in
`SECURITY.md`. This includes issues involving secret exposure, unsafe command
execution, sandbox bypass, prompt redaction gaps, CI safety, or generated
artifact handling.

Do not open a public issue with exploit details or secret material.

## Proposing Changes

For behavior changes, explain:

- What problem the change solves.
- Which files or commands are affected.
- Why the change preserves the project's conservative safety posture.
- How you validated it locally.

Prefer small pull requests over broad rewrites.

## Pull Request Expectations

- Keep diffs focused.
- Update documentation when behavior changes.
- Avoid unrelated formatting churn.
- Do not change releases, tags, or generated artifacts in a feature PR.
- Do not introduce new automation that commits, pushes, deploys, installs
  dependencies, or widens sandbox permissions without prior maintainer review.

## Local Validation

If Pester is installed, run the safety tests before opening a pull request:

```powershell
Invoke-Pester -Path .\tests\AIServiceTemplate.Safety.Tests.ps1
```

If you cannot run the tests, state that in the pull request and include the
reason.

## Files And Artifacts That Must Not Be Committed

Do not commit:

- `ai-runs/**`
- `.claude/**`
- Secrets
- `.env` files
- `*.pem`
- `*.key`
- Generated local artifacts

If a change appears to require committing one of these files, stop and discuss
the safer path first.
