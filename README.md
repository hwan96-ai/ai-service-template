# AI Service Template

Local safety harness for Codex CLI and Claude Code CLI in real repos.

You want Codex CLI or Claude Code CLI to help in a real repository. You do not want them to commit, push, deploy, install packages, or bypass review. This project is the local safety layer between those AI tools and your repository.

This is not a replacement for Codex CLI or Claude Code CLI. It wraps local workflow scripts, prompts, guardrails, test detection, and final handoff artifacts around those tools. `/goal` and `/ralph` are workflow prompt conventions for Codex CLI / Claude Code style sessions, not PowerShell commands and not the full runtime. End-to-end execution still requires local CLI setup, authentication, and explicit script flags.

The current implementation is Windows + PowerShell focused. The default posture is dry-run and prompt-only. Real AI execution requires explicit opt-in, and the harness never commits, pushes, deploys, installs dependencies, or uses permissive sandbox flags on its own. Every run ends with a human-reviewable `AI_FINAL_HANDOFF.md`.

> Template version: `0.6.0`. See `TEMPLATE_CHANGELOG.md` for release history.

For safety boundaries, trust assumptions, and non-goals, see [SECURITY.md](SECURITY.md).

## Requirements

For baseline dry-run and prompt-only use:

- Windows 10/11
- PowerShell 5.1 or newer
- Git, with Git for Windows recommended
- The copied harness files in the target service repo

For real AI execution, also add:

- Codex CLI installed and authenticated for real Codex execution
- Claude Code CLI installed and authenticated for real Claude review
- ChatGPT/OpenAI account capable of using Codex
- Claude account capable of using Claude Code

Prompt-only and dry-run checks can be useful before both CLIs are ready.

## Optional Tools

- Claude Desktop or Claude Code Desktop
- Claude Code VS Code extension
- Codex web or IDE extension
- Pester for PowerShell self-tests

## Not Required

- GPT API automation
- Auto-commit
- Auto-push
- Deployment credentials
- Dependency installation during harness runs

## Preflight Check

Run these from the repository where you plan to use the harness:

```powershell
git --version
$PSVersionTable.PSVersion
codex --version
claude --version
```

## Self-Tests

If Pester is already installed, run the safety self-tests without installing
anything:

```powershell
Invoke-Pester -Path .\tests\AIServiceTemplate.Safety.Tests.ps1
```

The tests use temporary directories and do not invoke Codex CLI or Claude Code CLI.

## 2-Minute Quickstart

If you cloned this template repo, first preview or copy it into a target service repo with `tools/copy-template-to-service.ps1`, or use the template repo only for inspection. The `cd D:\your-service-repo` commands below assume the harness files already exist in that target service repo.

Start with dry-run and prompt-only modes. These commands create local review artifacts, but they do not run real Codex or Claude, do not run tests, and do not commit, push, deploy, install dependencies, or use permissive sandbox flags.

```powershell
cd D:\your-service-repo

powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -DryRun -Goal "service smoke test"

powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -Implementer codex -DryRun -Goal "Generate a Codex implementation prompt only"

powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -Reviewer claude -DryRun -Goal "Generate a Claude review prompt only"
```

Expected output: each command writes a timestamped local folder under `ai-runs/` with a human-reviewable `AI_FINAL_HANDOFF.md`. The Codex command also writes a Codex prompt artifact without executing Codex. The Claude command writes a Claude review prompt artifact without executing Claude. Review the handoff before deciding whether to opt in to real AI execution.

See [examples/sample-AI_FINAL_HANDOFF.md](examples/sample-AI_FINAL_HANDOFF.md) for a sanitized sample handoff. For the full safe progression, use `TEMPLATE_USAGE.md`.

## Why Not Just Use Codex, Claude Code, Cursor, Or AGENTS.md?

This project is most useful when you already want Codex CLI and Claude Code CLI,
but want stronger local guardrails around them. It does not replace those tools;
it makes their use more deliberate, reviewable, and repeatable.

| Option | What it is good for | What this harness adds |
| ------ | ------------------- | ---------------------- |
| Raw Codex CLI | Direct implementation help | Conservative run wrapper, dry-run first, sandbox expectations, generated artifacts, no auto-commit, no auto-push, no deploy, no dependency install, and final human handoff. |
| Raw Claude Code CLI | Interactive planning, review, and editing | Review-only path, prompt artifacts, explicit execution gates, and a no-commit/no-push/no-deploy policy. |
| Cursor / aider / similar tools | Productive agentic coding | This project intentionally reduces autonomy with prompt-only defaults, local safety gates, explicit opt-in execution, and bounded fix loops. |
| README.md only | Human-readable guidance | PowerShell scripts, detected-test summaries, local run folders, and handoff artifacts that make the workflow repeatable. |
| AGENTS.md / CLAUDE.md only | Agent instructions | Copy and validation scripts, run artifacts, conservative execution gates, bounded fix loops, and a final human handoff. |

## Who This Is For

- Developers who want Codex CLI or Claude Code CLI help in a real repo while keeping final control local
- Teams that want prompt-only review artifacts before allowing AI execution
- Maintainers who need a repeatable handoff showing git status, detected tests, AI output, review notes, and remaining risks
- Users who want explicit gates before any implementer or reviewer process runs

## Who This Is Not For

- Users looking for a hosted AI coding service
- Teams that want automatic commits, pushes, deploys, or dependency installation
- Projects that need Linux/macOS-first shell support today
- Workflows that intentionally require permissive sandbox flags or bypassed review

## What The Harness Does

- Copies reusable AI control documents and PowerShell scripts into a service repo
- Collects redacted git status and diff summaries without reading secret file contents
- Detects likely local test commands without installing dependencies
- Runs selected opt-in local checks from trusted repositories only when requested
- Generates Codex implementation prompts and can run Codex only with explicit opt-in
- Generates Claude review prompts and can run Claude review-only only with explicit opt-in
- Supports a bounded Codex and Claude fix loop when explicitly enabled
- Writes local run artifacts under `ai-runs/` and ends with `AI_FINAL_HANDOFF.md`

## What The Harness Does Not Do

- It does not understand your service until you fill in `AI_PRODUCT_SPEC.md` and `AI_TASK_QUEUE.md`
- It does not replace Codex CLI, Claude Code CLI, ChatGPT, or Claude accounts
- It does not run Codex or Claude unless the matching run switches are provided
- It does not commit, push, deploy, install dependencies, tag releases, or merge branches
- It does not use `danger-full-access`, bypass, yolo, full-auto, or other permissive sandbox flags
- It does not guarantee trusted repository test scripts are side-effect free; it deny-lists wrapper command text
- It does not replace human review; it creates artifacts for human review

## Repository Layout

```text
D:\ai-service-template
|-- AI_PRODUCT_SPEC.md
|-- AI_ACCEPTANCE_CRITERIA.md
|-- AI_TASK_QUEUE.md
|-- AI_WORKFLOW.md
|-- AGENTS.md
|-- CLAUDE.md
|-- README.md
|-- TEMPLATE_USAGE.md
|-- SERVICE_ONBOARDING_CHECKLIST.md
|-- TEMPLATE_CHANGELOG.md
|-- TEMPLATE_MANIFEST.json
|-- examples/
|   `-- sample-AI_FINAL_HANDOFF.md
|-- ai-runs/
|   `-- .gitkeep
`-- tools/
    |-- ai-autopilot.ps1
    |-- collect-context.ps1
    |-- detect-tests.ps1
    |-- write-final-handoff.ps1
    |-- write-claude-review-prompt.ps1
    |-- write-codex-implementation-prompt.ps1
    |-- write-codex-fix-prompt.ps1
    |-- copy-template-to-service.ps1
    `-- validate-template-install.ps1
```

### Key Files

| File | Role |
|------|------|
| `tools/ai-autopilot.ps1` | Main local orchestrator. This is where a harness run starts. |
| `AI_PRODUCT_SPEC.md` | Human-written service context for the target repo. |
| `AI_TASK_QUEUE.md` | Human-written work queue for the target repo. |
| `AI_ACCEPTANCE_CRITERIA.md` | Completion and safety criteria. |
| `AGENTS.md` | Guardrails for Codex CLI. |
| `CLAUDE.md` | Guardrails for Claude Code CLI. |
| `TEMPLATE_USAGE.md` | Deeper usage guide. |
| `SERVICE_ONBOARDING_CHECKLIST.md` | Checklist for applying the harness to a service repo. |
| `tools/copy-template-to-service.ps1` | Preview-first copy script for installing the harness into another repo. |
| `tools/validate-template-install.ps1` | Install validator and dry-run smoke-check helper. |
| `examples/sample-AI_FINAL_HANDOFF.md` | Sanitized sample output so you can see the review artifact before running the harness. |
| `ai-runs/` | Local run artifacts. Timestamped run folders are ignored by git. |

## Detailed Usage

For the full install and operating guide, see [TEMPLATE_USAGE.md](TEMPLATE_USAGE.md).
For a step-by-step adoption checklist, see
[SERVICE_ONBOARDING_CHECKLIST.md](SERVICE_ONBOARDING_CHECKLIST.md).

Start with dry-run and prompt-only commands. Move to real Codex or Claude
execution only after the generated prompts and `AI_FINAL_HANDOFF.md` are
reviewed by a human.

## Release History

This template is versioned in [TEMPLATE_CHANGELOG.md](TEMPLATE_CHANGELOG.md).
The README intentionally describes current capabilities instead of construction
phases.

## License

This repository is released under the MIT License. See [LICENSE](LICENSE).
