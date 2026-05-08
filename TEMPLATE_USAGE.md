# TEMPLATE_USAGE.md — Main user guide

This guide is the practical "how do I actually use it" companion to
`README.md`. Read this if you have already read the README and want to start
running the harness in a real service repo.

> **Template version:** `0.6.0`
>
> **Phases shipped:** 1, 2, 3, 4, 5, 6.

## Table of contents

- [A. Quick start for a new service repo](#a-quick-start-for-a-new-service-repo)
- [B. Recommended safe progression](#b-recommended-safe-progression)
- [C. Example commands](#c-example-commands)
- [D. Safety explanation](#d-safety-explanation)
- [E. Troubleshooting](#e-troubleshooting)

---

## A. Quick start for a new service repo

This is the path you should follow the **first** time you copy this template
into a real repo.

1. **Copy template files into the target repo (preview, then apply).**

   ```powershell
   # Step 1a — preview only. No files are written.
   powershell -ExecutionPolicy Bypass -File .\tools\copy-template-to-service.ps1 `
       -TargetRepo D:\path\to\your-service-repo

   # Step 1b — apply once the preview list looks correct.
   powershell -ExecutionPolicy Bypass -File .\tools\copy-template-to-service.ps1 `
       -TargetRepo D:\path\to\your-service-repo -Apply

   # Step 1c — (optional) append local-only ignore rules.
   powershell -ExecutionPolicy Bypass -File .\tools\copy-template-to-service.ps1 `
       -TargetRepo D:\path\to\your-service-repo -Apply -IncludeLocalGitignoreRules
   ```

   The copy script never overwrites existing `AI_PRODUCT_SPEC.md`,
   `AI_TASK_QUEUE.md`, or other control docs unless you explicitly pass
   `-OverwriteControlDocs`. It never copies `ai-runs/<timestamp>/`, `.claude/`,
   or `.git/`.

2. **Validate the install.**

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\validate-template-install.ps1 `
       -TargetRepo D:\path\to\your-service-repo
   ```

   This reports `pass` / `warn` / `fail` per check and exits non-zero if a
   required file is missing.

3. **Fill in `AI_PRODUCT_SPEC.md`** with what the service is, who it serves,
   what is in scope, what is out of scope, and how you will know the next
   release is done.

4. **Fill in `AI_TASK_QUEUE.md`** with at least one real task ID (e.g. `T-101`)
   and a short title describing the change you want.

5. **Run a `-DryRun` smoke test** from the target repo:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
       -DryRun -Goal "service smoke test"
   ```

   This creates one timestamped folder under `ai-runs/`, collects redacted git
   context, runs detection, and writes `AI_FINAL_HANDOFF.md`. It does **not**
   invoke Codex, Claude, or tests.

6. **Run unit-level safe tests** (still no Codex, still no Claude):

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
       -TestLevel unit -Goal "unit validation"
   ```

7. **Generate the Codex prompt only** (still no Codex CLI invocation):

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
       -Implementer codex -DryRun -Goal "Codex prompt only"
   ```

   This writes `codex-implementation-prompt.md` and a placeholder
   `codex-output.md`. You can hand the prompt to Codex CLI yourself.

8. **Generate the Claude review prompt only** (still no Claude invocation):

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
       -Reviewer claude -DryRun -Goal "Claude review prompt only"
   ```

9. **Only later**, after you have manually confirmed your local Codex CLI and
   Claude CLI accept the locked invocation patterns, try `-RunImplementer` and
   `-RunReviewer`. See section B for the safe progression.

---

## B. Recommended safe progression in a real service repo

Move down the list one row at a time. Stop at the first failure and read
`AI_FINAL_HANDOFF.md` before going further.

| Order | Command shape                                                                | What it does                                                       |
|-------|------------------------------------------------------------------------------|--------------------------------------------------------------------|
| 1     | `-DryRun -Goal "..."`                                                        | Detect, collect, write handoff. No tests. No Codex. No Claude.     |
| 2     | `-TestLevel unit -Goal "..."`                                                | Add safe local tests. No Codex. No Claude.                         |
| 3     | `-Implementer codex -DryRun -Goal "..."`                                     | Generate the Codex prompt; do not run Codex.                       |
| 4     | `-Reviewer claude -DryRun -Goal "..."`                                       | Generate the Claude review prompt; do not run Claude.              |
| 5     | `-Implementer codex -RunImplementer -TestLevel unit -Goal "..."`             | One-shot Codex + unit tests. Still no Claude.                      |
| 6     | `-Reviewer claude -RunReviewer -TestLevel unit -Goal "..."`                  | Run review-only Claude. Still no Codex.                            |
| 7     | `-Implementer codex -RunImplementer -Reviewer claude -RunReviewer -TestLevel unit -Goal "..."` | One-shot Codex + Claude review (no fix loop yet).      |
| 8     | Add `-EnableFixLoop -MaxIterations 2` (cap is 3)                             | Bounded Codex ↔ Claude fix loop. Conservative diff caps stay on.   |

Do **not** start at row 8. The fix loop is only safe after you have personally
verified rows 1–7 against your local CLI versions.

---

## C. Example commands

These are exact commands. Copy-paste, change the `-Goal`, and run.

```powershell
# Phase 1 / 2 — safe defaults: no tests, no Codex, no Claude.
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -DryRun -Goal "service smoke test"

# Phase 2 — run safe unit-level tests only.
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -TestLevel unit -Goal "unit validation"

# Phase 4 — generate the Codex prompt without invoking Codex CLI.
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Implementer codex -DryRun -Goal "Codex prompt only"

# Phase 3 — generate the Claude review prompt without invoking Claude CLI.
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Reviewer claude -DryRun -Goal "Claude review prompt only"

# Phase 4 — actually run Codex CLI once (workspace-write sandbox), then unit tests.
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Implementer codex -RunImplementer -TestLevel unit -Goal "one-shot implementation"

# Phase 5 — bounded Codex <-> Claude fix loop, capped at 2 iterations.
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Implementer codex -RunImplementer `
    -Reviewer claude -RunReviewer `
    -EnableFixLoop -MaxIterations 2 -TestLevel unit -Goal "bounded loop"
```

After every command, the artifacts you care about are:

- `ai-runs/<timestamp>/AI_FINAL_HANDOFF.md` — read this last.
- `ai-runs/<timestamp>/codex-output.md` (if Codex was requested).
- `ai-runs/<timestamp>/claude-review.md` (if Claude was requested).
- `ai-runs/<timestamp>/test-summary.json` and `test-output.txt`.
- `ai-runs/<timestamp>/loop-summary.json` (only when `-EnableFixLoop` was set).

---

## D. Safety explanation

The harness is intentionally boring on purpose. The following are **never**
performed automatically:

- **No auto-commit.** `-AutoCommit` is refused with a clear message before any
  run folder is created.
- **No git push.** The harness never invokes `git push`, `git tag`, or any
  remote operation.
- **No deploy.** The harness never invokes a deploy command. It rejects any
  command text containing the word `deploy`.
- **No dependency install.** `npm install`, `pnpm install`, `yarn install`,
  `pip install`, `poetry install`, `uv add`, etc. are blocked by a denylist.
- **No destructive cleanup.** `rm -rf`, `Remove-Item -Recurse -Force` outside
  the active run folder, `git reset --hard`, force pushes, and `git clean` are
  all blocked.
- **`ai-runs/` is ignored.** The repo's `.gitignore` ignores `ai-runs/*` while
  preserving the tracked `ai-runs/.gitkeep` sentinel. Never commit
  timestamped run folders.
- **`.claude/` is ignored.** Local Claude Code CLI state is per-machine and is
  excluded from version control.
- **Human review is always required.** The handoff document never claims a
  run is "done". The Result line surfaces what passed, what failed, and what
  still needs human approval.
- **`-DryRun` always wins.** It suppresses Codex execution, Claude execution,
  and test execution even if `-RunImplementer`, `-RunReviewer`,
  `-EnableFixLoop`, or `-TestLevel` are also set.
- **Codex sandbox is locked.** Only `codex exec --sandbox workspace-write` is
  used. `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`,
  `--full-auto`, yolo, and bypass are never used.
- **Claude review mode is locked.** Only `claude -p ... --output-format text
  --tools ""` is used. `--dangerously-skip-permissions`, `acceptEdits`,
  `bypassPermissions`, allowed-edit, and allowed-bash flags are never used.
- **Phase 6 (this packaging layer) does not change any of the above.** The
  copy script is preview-only by default, refuses to overwrite control docs
  unless asked, and never runs git/install/delete.

---

## E. Troubleshooting

### "The local Claude CLI rejects `--tools ""`"

If your local Claude Code CLI version does not accept `claude -p <prompt>
--output-format text --tools ""`, the harness writes a clear
`Automatic Claude review could not be executed safely` message into
`claude-review.md` and continues to the final handoff. **No alternative
permissive Claude modes are attempted.** Hand the prompt
(`claude-review-prompt.md`) to Claude yourself, then paste the response back
into `claude-review.md` if you want it included in the handoff.

### "The local Codex CLI rejects `--sandbox workspace-write`"

Same pattern. The harness only attempts `codex exec --sandbox workspace-write
<prompt>`. If your Codex CLI version does not accept that exact pattern,
`codex-output.md` will say `Automatic Codex implementation could not be
executed safely`, and the harness continues to the final handoff. **No
permissive Codex modes are attempted.** You can hand
`codex-implementation-prompt.md` to Codex yourself.

### "No tests found"

`detect-tests.ps1` writes `noTestsFound: true` into `detected-tests.json` and
the harness records a clear "no automated verification was available" message
in the handoff Result line. This is never reported as success. Add at least
one safe test command (typecheck, lint, or unit) to the target service repo
and re-run.

### "MaxDiffStatLines exceeded" (fix-loop only)

The bounded fix loop halts as soon as the cumulative diff insertions+deletions
exceed `-MaxDiffStatLines` (default `120`). The Result line will say
`fix loop halted by Phase 5 safety check (max-diff-stat-exceeded)`. This is
intentional. Either narrow the task scope, raise the cap on the next
invocation (e.g. `-MaxDiffStatLines 200`), or stop and review the diff by
hand.

### "MaxChangedFiles exceeded" (fix-loop only)

Same shape, but for the cumulative changed-file count (default `12`). Either
narrow scope or raise the cap on the next invocation.

### "MaxIterations refused"

`-MaxIterations` is hard-capped at `3`. Values `< 1` or `> 3` cause the
script to abort cleanly with exit code `2` **before** any run folder is
created. Use `-MaxIterations 2` or `-MaxIterations 3`.

### "Cannot run scripts on this system" / Execution policy issues on Windows PowerShell

If PowerShell refuses to run any of the scripts:

```
.\tools\ai-autopilot.ps1 : File ... cannot be loaded because running
scripts is disabled on this system.
```

Two safe options:

1. **Per-invocation override (recommended):** every example in this guide
   already starts with `powershell -ExecutionPolicy Bypass -File ...`. That
   override applies only to that one invocation; nothing is changed
   permanently.
2. **Per-user override (if you control the machine):** open PowerShell and
   run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`. Do **not** set
   `Bypass` machine-wide.

### "ai-runs is full / disk usage growing"

`ai-runs/` is local-only and gitignored. You can delete entire timestamped
folders inside `ai-runs/` whenever you want. Keep `ai-runs/.gitkeep`. Do not
hand-edit a folder once a run is in progress.

### "Copy preview shows files I do not want"

Re-run `copy-template-to-service.ps1` without `-Apply` and read the preview
output. Files originate from `TEMPLATE_MANIFEST.json`. To skip something
template-side, fork the template; do not edit the manifest in the target.

### "validate-template-install.ps1 reports a warning about `.gitignore`"

Warnings are not failures. The validator warns when the target's `.gitignore`
does not contain `ai-runs/*` and `.claude/` rules. Re-run the copy script
with `-IncludeLocalGitignoreRules -Apply` to append them, or add them by hand.
