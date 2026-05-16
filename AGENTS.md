# AGENTS.md - Coding Agent Instructions

This file is for Codex, Cursor, and other AI coding agents working in a repo
that uses this template. Use uppercase `AGENTS.md`.

## Start Here

Read `AI_AGENT_BOOTSTRAP.md` first. Then read every rule file under
`.claude/rules/` (listed below) before proposing or making changes.

**Required:** Before any action — planning, review, or editing — you MUST
read every linked rule file below in order. Reading only this index is
insufficient. Each rule encodes safety guarantees that the others depend on.

## Rule Index

1. [Start Here](.claude/rules/start-here.md) — required reads and entry point.
2. [Operating Mode](.claude/rules/operating-mode.md) — default mode and hard prohibitions.
3. [Editing Rules](.claude/rules/editing-rules.md) — surgical-edit discipline.
4. [Escape Hatch](.claude/rules/escape-hatch.md) — what to do on conflict.

These rules are the single source of truth shared by both Codex and Claude
entrypoints. Do not embed copies elsewhere; link to the files above.
