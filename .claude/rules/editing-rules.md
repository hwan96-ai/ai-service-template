---
name: editing-rules
description: Surgical-edit discipline scoped to the active task allow-list.
type: rule
owner: harness-maintainers
applies_to: [claude-code, codex-cli, cursor, gemini-cli]
---

# Editing Rules

- Make minimal edits only within the active task allow-list.
- Map every change to the active task and acceptance criteria.
- Do not opportunistically refactor unrelated code.
- Prefer dry-run or prompt-only workflow steps before runtime implementation.
- Report uncertainty instead of guessing.
