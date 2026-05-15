# Quickstart — First 5 Minutes

For developers landing on this repo for the first time. Goal: from clone to a
proven dry-run that confirms your AI agent reads the safety rules.

## 30 seconds — Verify

```powershell
pwsh -File bin/agent-dry-run.ps1
```

Confirms the four rule files exist and prints a self-check prompt to paste
into your agent. No network, no AI call, no install.

## 30 seconds — Find your entrypoint

```powershell
pwsh -File bin/agent-bootstrap.ps1 claude   # → CLAUDE.md
pwsh -File bin/agent-bootstrap.ps1 codex    # → AGENTS.md
pwsh -File bin/agent-bootstrap.ps1 cursor   # → AGENTS.md
```

Outputs the right entrypoint file + the four linked rules. Read all of them
before asking the agent to do anything.

## 1 minute — First task

1. Copy the self-check prompt from `agent-dry-run.ps1` into your agent.
2. Confirm the agent quotes one verbatim sentence from each of the four rule
   files. If it returns generic text, the agent did NOT load the rules.
3. Once verified, you can hand it a real task — but only inside the active
   allow-list (`AI_TASK_QUEUE.md`).

## 3 minutes — Read the rules yourself

Open each in turn:

1. [`.claude/rules/start-here.md`](.claude/rules/start-here.md)
2. [`.claude/rules/operating-mode.md`](.claude/rules/operating-mode.md)
3. [`.claude/rules/editing-rules.md`](.claude/rules/editing-rules.md)
4. [`.claude/rules/escape-hatch.md`](.claude/rules/escape-hatch.md)

Total reading time: under 2 minutes. These are the actual safety contract.

## What this template does NOT do

- Auto-commit, auto-push, auto-deploy, auto-install dependencies
- Read or print secrets
- Edit files outside the active task allow-list

Every safety rule lives in `.claude/rules/`. If you want stricter rules for
your downstream service, edit those files — both Claude and Codex
entrypoints will pick up the changes.

## Next

- Full docs: [README.md](README.md) · [README_KO.md](README_KO.md)
- Onboarding checklist: [SERVICE_ONBOARDING_CHECKLIST.md](SERVICE_ONBOARDING_CHECKLIST.md)
- Template usage: [TEMPLATE_USAGE.md](TEMPLATE_USAGE.md)
- Changelog: [TEMPLATE_CHANGELOG.md](TEMPLATE_CHANGELOG.md)
