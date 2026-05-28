# CLAUDE.md - Claude Code Router

This file is the concise entrypoint for Claude Code. Use uppercase
`CLAUDE.md`; do not create a lowercase `claude.md`.

## Required Read Order

1. Read `AI_AGENT_BOOTSTRAP.md`.
2. Read every required rule file referenced by the bootstrap.
3. Read the shared instruction index at
   [docs/claude/README.md](docs/claude/README.md).

## Claude Code Boundary

Claude Code should operate in planning, review, or surgical-edit mode for this
repository. The durable instructions for project context, workflow, testing,
security, portfolio handling, and git hygiene live under `docs/claude/`.

Do not expose secrets, credentials, deployment tokens, private customer
details, internal URLs, proprietary implementation notes, or non-public business
information. Public portfolio or showcase extraction must happen in a separate
sanitized repository, never by making this original repository public.
