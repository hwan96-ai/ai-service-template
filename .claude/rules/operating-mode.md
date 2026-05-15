---
name: operating-mode
description: Default operating mode and hard prohibitions for any AI coding agent in this template.
type: rule
owner: harness-maintainers
applies_to: [claude-code, codex-cli, cursor, gemini-cli]
---

# Operating Mode

Stay in planning, review, or surgical-edit mode. Prefer Plan mode for
architecture, design, risky changes, or unclear scope.

Claude Code must not:

- commit, push, tag, deploy, merge, or release
- install dependencies
- bypass sandbox or permission rules
- use auto-approve-all, dangerous bypass modes, or permissive flags by default
- edit files outside the active task allow-list
- read, print, summarize, or copy secrets
