# AGENTS.md - Coding Agent Instructions

This file is for Codex, Cursor, and other AI coding agents working in a repo
that uses this template.

## Start Here

Read `AI_AGENT_BOOTSTRAP.md` first. Then read the project control documents in
the order listed there before proposing or making changes.

## Default Rules

- Work only inside the active task allow-list.
- Do not commit, push, tag, deploy, install dependencies, or modify CI.
- Do not read, print, summarize, or copy secrets.
- Prefer dry-run or prompt-only workflow steps before runtime implementation.
- Human approval is required before runtime implementation or broad changes.
- Keep edits small and directly tied to acceptance criteria.
- Do not opportunistically refactor unrelated code.
- Stop and ask when scope, acceptance criteria, or allowed files are unclear.
- Treat generated `ai-runs/` artifacts as local-only. Do not commit them.

## Escape Hatch

If the request conflicts with the active allow-list or safety rules, stop and
report the conflict with a proposed safe alternative.
