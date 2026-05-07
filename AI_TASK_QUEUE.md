# AI Task Queue

> One row per task. Task IDs use the format `T-NNN` (zero-padded). Update Status manually as work progresses. Phase 1 of the harness does not modify this file automatically.

## Status legend

- `todo` — not started
- `doing` — in progress (only one at a time, ideally)
- `blocked` — waiting on input or decision
- `done` — completed and verified
- `cancelled` — no longer needed

## Queue

| ID    | Title                                          | Status | Notes                                    |
| ----- | ---------------------------------------------- | ------ | ---------------------------------------- |
| T-001 | (sample) Verify Phase 1 harness end-to-end     | todo   | Run `ai-autopilot.ps1 -DryRun` and read AI_FINAL_HANDOFF.md |

<!-- Add new tasks above this line -->
