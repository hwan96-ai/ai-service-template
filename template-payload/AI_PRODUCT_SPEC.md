# AI Product Spec

This file describes the service repository after this template is copied into it.
Customize it before asking Codex CLI or Claude Code CLI to reason about real
work. The harness reads this as product context; it does not discover product
intent on its own.

## Customization Checklist

- Replace bracketed guidance with information about the target service.
- Keep secrets, tokens, customer data, and environment-specific credentials out
  of this file.
- Write enough detail that a reviewer can understand the goal without opening
  every source file.
- Update this file when the service scope or success criteria change.

## Service Overview

Service name: `<service-name>`

What the service does:

`<Describe the service in one or two short paragraphs. Include the main user
workflow, the business or developer problem it solves, and the most important
runtime boundaries.>`

Primary users:

- `<user group 1>`
- `<user group 2>`

Secondary users or stakeholders:

- `<stakeholder or operator group>`

## Current Goal

Describe the next change you want the harness to support.

- Goal ID or task ID: `<T-101 or similar>`
- Goal summary: `<one sentence>`
- Why this matters now: `<one sentence>`
- Desired outcome: `<what should be true after the work is done>`

## In Scope

List what the next iteration may change.

- `<allowed product behavior, UI area, API, script, or document>`
- `<allowed test or validation update>`
- `<allowed documentation update>`

## Out Of Scope

List what should not be changed during this iteration.

- `<unrelated feature or module>`
- `<deployment, migration, or operational area not being touched>`
- `<anything that needs a separate approval>`

## Success Criteria

Use concrete checks. A human should be able to decide whether the work is done.

- `<observable behavior or artifact>`
- `<test, lint, typecheck, or manual verification>`
- `<documentation or handoff requirement>`

## Safety And Data Constraints

- Secrets must not be read, printed, copied, or summarized.
- Dependency installation is not part of a normal harness run.
- Commit, push, tag, merge, and deploy operations remain human actions.
- Any change outside the active task scope should be treated as a stop signal.

## Important Project Context

Architecture notes:

- `<main runtime, framework, or service boundary>`
- `<important directories or entry points>`

Testing notes:

- `<preferred local checks, such as unit tests, lint, or typecheck>`
- `<checks that are slow, flaky, or require special setup>`

Operational notes:

- `<manual setup, external service dependency, or release constraint>`

## Open Questions

Capture questions that should be answered before real implementation begins.

- `<question>`
- `<question>`
