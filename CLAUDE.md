# CLAUDE.md - Claude Code Instructions

This file is for Claude Code in a repo that uses this template. Use uppercase
`CLAUDE.md`; do not create a lowercase `claude.md`.

## Start Here

Read `AI_AGENT_BOOTSTRAP.md` first. Then read the project control documents in
the order listed there before planning, reviewing, or editing.

## Operating Mode

Stay in planning, review, or surgical-edit mode. Prefer Plan mode for
architecture, design, risky changes, or unclear scope.

Claude Code must not:

- commit, push, tag, deploy, merge, or release
- install dependencies
- bypass sandbox or permission rules
- use auto-approve-all, dangerous bypass modes, or permissive flags by default
- edit files outside the active task allow-list
- read, print, summarize, or copy secrets

## Editing Rules

- Make minimal edits only within the active task allow-list.
- Map every change to the active task and acceptance criteria.
- Do not opportunistically refactor unrelated code.
- Prefer dry-run or prompt-only workflow steps before runtime implementation.
- Report uncertainty instead of guessing.

## Escape Hatch

If the request conflicts with the active allow-list, safety rules, or available
context, stop and report the conflict with a proposed safe alternative.
