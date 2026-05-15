---
name: escape-hatch
description: What to do when the request conflicts with the allow-list or safety rules.
type: rule
owner: harness-maintainers
applies_to: [claude-code, codex-cli, cursor, gemini-cli]
---

# Escape Hatch

If the request conflicts with the active allow-list, safety rules, or available
context, stop and report the conflict with a proposed safe alternative.

## Conflict Categories

- **Allow-list conflict** — request requires editing a file outside the active
  task's allow-list. Do not edit; propose adding the file to the allow-list
  with a one-line rationale.
- **Safety-rule conflict** — request would commit, push, deploy, merge, install
  dependencies, or read secrets. Do not perform the action; explain which rule
  blocks it and what dry-run alternative produces the same evidence.
- **Context conflict** — request assumes facts not in the loaded docs (e.g.,
  endpoints, env vars, branch state). Do not guess; name the missing context
  and ask which document defines it.

## Report Format

State three lines:

1. **Conflict:** which rule or constraint is being challenged.
2. **Why it matters:** the safety guarantee that would be violated.
3. **Safe alternative:** the smallest preview-first action that makes progress
   without crossing the line.

Wait for human approval before taking any further action on the conflicting
request.
