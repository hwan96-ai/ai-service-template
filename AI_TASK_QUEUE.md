# AI Task Queue

> One row per task. Task IDs use the format `T-NNN` (zero-padded). Update Status manually as work progresses. Phase 1 of the harness does not modify this file automatically.

## Status legend

- `todo` — not started
- `doing` — in progress (only one at a time, ideally)
- `blocked` — waiting on input or decision
- `done` — completed and verified
- `cancelled` — no longer needed

## Queue

| ID    | Title                                                       | Status | Notes                                                                 |
| ----- | ----------------------------------------------------------- | ------ | --------------------------------------------------------------------- |
| T-001 | (sample) Verify Phase 1 harness end-to-end                  | todo   | Run `ai-autopilot.ps1 -DryRun` and read AI_FINAL_HANDOFF.md           |
| T-002 | Add Phase 2 test detection and optional test execution      | done   | Conservative harness enhancement; no Codex/Claude execution yet       |
| T-003 | Add Phase 3 Claude review prompt and optional reviewer execution | done | Reviewer-only; no Codex/fix loop yet                                  |
| T-004 | Add Phase 4 Codex one-shot implementation support           | done   | One-shot implementer only; no retry/fix loop yet                      |
| T-005 | Add Phase 5 bounded Codex ↔ Claude fix loop                 | done   | Opt-in via -EnableFixLoop; capped at 3 iterations; loop never bypasses safety |
| T-006 | Add Phase 6 template packaging and service onboarding support | done | Reuse support; no new Codex/Claude loop behavior. Adds README, TEMPLATE_USAGE, SERVICE_ONBOARDING_CHECKLIST, TEMPLATE_CHANGELOG, TEMPLATE_MANIFEST.json, copy-template-to-service.ps1 (preview-by-default), and validate-template-install.ps1 (`-RunSmoke` skips Codex/Claude/tests). Light-touch banner + TemplateVersion in autopilot / handoff. |

<!-- Add new tasks above this line -->
