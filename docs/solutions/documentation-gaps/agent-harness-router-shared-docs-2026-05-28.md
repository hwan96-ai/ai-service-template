---
title: Agent Harness Router And Shared Docs Migration
date: 2026-05-28
category: docs/solutions/documentation-gaps
module: agent harness documentation
problem_type: documentation_gap
component: documentation
severity: low
applies_when:
  - migrating duplicated root agent instructions into shared durable docs
  - preserving privacy and portfolio-safety requirements in harness documentation
  - validating documentation-only agent harness changes
tags: [agent-harness, documentation, routers, privacy, portfolio-safety]
---

# Agent Harness Router And Shared Docs Migration

## Context

The repository had concise root agent files that pointed directly at required
rule files, but the task required a router/shared-doc structure: `AGENTS.md`
for Codex and general agents, `CLAUDE.md` for Claude Code, and durable shared
instructions under `docs/claude/`.

The main friction was preserving existing safety guidance while avoiding broad
rewrites and unsupported claims. A second friction point was the conflict
between a task-level request to commit and push and repository safety rules
that treat those actions as human-controlled.

## Guidance

Keep root agent files short and use them as routers. Preserve their useful
meaning by linking to the required bootstrap, rule files, and shared instruction
index instead of copying the same long body into both files.

For shared docs, split durable guidance by purpose:

- project overview and non-goals
- repository map and current technology evidence
- development workflow
- testing and validation
- security and secrets
- portfolio showcase rules
- release and git hygiene

Document only what the repository proves. In this case, evidence supported a
Windows/PowerShell harness, Pester safety tests, template payload docs, local
`ai-runs/` artifacts, and a no-auto-commit/no-auto-push stance. It did not
support claims about product runtime behavior, frontend frameworks, deployment
architecture, or package managers.

## Why This Matters

Router files are read first by multiple tools. Keeping them concise reduces
drift, while shared docs make the durable guidance discoverable and easier to
maintain.

Privacy and portfolio-readiness need explicit instructions because this
repository can be private or portfolio-sensitive. Public showcase work should
happen in a separate sanitized repository, not by making the original repository
public.

## When to Apply

- When root agent files duplicate long instruction bodies
- When adding tool-specific entrypoints that should share one source of truth
- When a private harness needs public-portfolio guardrails
- When a documentation-only task has a strict file allow-list

## Examples

Before:

```text
AGENTS.md and CLAUDE.md each duplicate the rule index and long instructions.
```

After:

```text
AGENTS.md -> AI_AGENT_BOOTSTRAP.md -> required rules -> docs/claude/README.md
CLAUDE.md -> AI_AGENT_BOOTSTRAP.md -> required rules -> docs/claude/README.md
docs/claude/* -> durable shared guidance by topic
```

## Mistakes And Failed Attempts

- A directory creation command hit a sandbox spawn failure even though the path
  was in the allowed documentation scope.
- The remote branch check needed direct remote evidence, not just local remote
  refs.
- `git diff --name-only` did not show newly created docs until they were added
  with intent-to-add or staged.

## Review Findings

- `git diff --check` passed for the documentation changes.
- Changed files stayed inside the task allow-list.
- Every `docs/claude` child document includes a `When To Use This` section.
- Relative links in `docs/claude/README.md` resolved successfully.

## Prevention Rules

- Use root agent files as routers and keep durable instruction bodies in shared
  docs.
- Verify untracked documentation files with intent-to-add or staging before
  relying on `git diff --name-only`.
- Treat commit and push requests as a separate safety boundary when repository
  rules say those actions remain human-controlled.
- For portfolio-sensitive repositories, document sanitized-repository public
  extraction explicitly.

## Related

- [Claude Instruction Index](../../claude/README.md)
