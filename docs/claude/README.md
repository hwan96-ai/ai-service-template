# Claude Instruction Index

## When To Use This

Use this index at the start of any Claude Code, Codex, Cursor, or other coding
agent session after reading `AI_AGENT_BOOTSTRAP.md` and the required rule files
it references.

## Purpose

The root `AGENTS.md` and `CLAUDE.md` files are routers. These documents are the
shared durable instruction source of truth for agents working in this
repository.

## Required Shared Docs

Read the documents that apply to the task before planning, reviewing, or
editing:

- [Project Overview](project-overview.md)
- [Repository Map](repository-map.md)
- [Development Workflow](development-workflow.md)
- [Testing And Validation](testing-and-validation.md)
- [Security And Secrets](security-and-secrets.md)
- [Portfolio Showcase Rules](portfolio-showcase-rules.md)
- [Release And Git Hygiene](release-and-git-hygiene.md)

For broad work, read all of them. For narrow work, read the overview, repository
map, and the task-specific document.

## Core Rule

This is a reusable AI service template and local safety harness. Preserve
template generality, work from repository evidence only, and keep privacy,
security, and portfolio readiness as first-class concerns.

`docs/solutions/` contains documented solutions to past problems, organized by
category with YAML frontmatter such as `module`, `tags`, and `problem_type`.
It is relevant when implementing or debugging in documented areas.
