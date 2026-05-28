# AGENTS.md - General Agent Router

This file is the concise entrypoint for Codex, Cursor, and other coding agents.
Keep durable project instructions in `docs/claude/` instead of duplicating them
here.

## Required Read Order

1. Read `AI_AGENT_BOOTSTRAP.md`.
2. Read every required rule file referenced by the bootstrap.
3. Read the shared instruction index at
   [docs/claude/README.md](docs/claude/README.md).

## Operating Boundary

This repository is a Windows/PowerShell AI coding safety harness, not a product
runtime. Work from repository evidence only, keep changes surgical, and do not
change product behavior while editing harness documentation.

Never expose secrets, credentials, deployment tokens, private customer details,
internal URLs, proprietary implementation notes, or non-public business
information. Public portfolio or showcase extraction must happen in a separate
sanitized repository, never by making this original repository public.
