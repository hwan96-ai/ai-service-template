# AI Service Template

A reusable, **safety-first** local AI automation harness you can copy into any
service repository. It coordinates Codex CLI (implementer), Claude Code CLI
(reviewer), local tests, and a final human handoff — without ever committing,
pushing, deploying, or installing dependencies on your behalf.

> **Template version:** `0.6.0` — see `TEMPLATE_CHANGELOG.md`.

## Who this is for

- A solo engineer or small team that wants to use Codex CLI and Claude Code CLI
  on a real service repo without giving them push or deploy access.
- Someone who is **not comfortable reading code deeply** and wants checklists,
  preview modes, and explicit human-approval gates by default.
- Anyone who wants the same harness, the same guardrails, and the same final
  `AI_FINAL_HANDOFF.md` flow across many service repositories.

## What this template includes

| Phase | What ships                                                                                  |
|-------|---------------------------------------------------------------------------------------------|
| 1     | Control documents + PowerShell harness foundation + final handoff document                 |
| 2     | Test detection + opt-in safe test execution + `test-output.txt` / `test-summary.json`       |
| 3     | Claude review prompt generation + opt-in review-only Claude execution                       |
| 4     | Codex one-shot implementation prompt + opt-in `codex exec --sandbox workspace-write`        |
| 5     | Bounded Codex ↔ Claude fix loop scaffolding (opt-in, capped at 3 iterations)                |
| 6     | Packaging, onboarding, copy-into-service tooling, install validator, manifest, changelog    |

All six phases are implemented. Phase 6 does not change Codex/Claude loop
behaviour; it only makes the template safe to **reuse**.

## Quick tour of the files

```
.
├── README.md                              # this file
├── TEMPLATE_USAGE.md                      # main user guide (read this second)
├── SERVICE_ONBOARDING_CHECKLIST.md        # non-developer checklist
├── TEMPLATE_CHANGELOG.md                  # phase-by-phase changelog
├── TEMPLATE_MANIFEST.json                 # machine-readable file list + version
├── AI_PRODUCT_SPEC.md                     # service-specific spec (you fill in)
├── AI_ACCEPTANCE_CRITERIA.md              # phase-by-phase acceptance gates
├── AI_TASK_QUEUE.md                       # task queue (you fill in)
├── AI_WORKFLOW.md                         # how the harness works, phase by phase
├── AGENTS.md                              # Codex CLI guardrails
├── CLAUDE.md                              # Claude Code CLI guardrails
├── tools/
│   ├── ai-autopilot.ps1                   # the harness orchestrator
│   ├── collect-context.ps1                # safe git context snapshot
│   ├── detect-tests.ps1                   # detects test runners (no install, no run)
│   ├── write-claude-review-prompt.ps1     # Phase 3 review prompt
│   ├── write-codex-implementation-prompt.ps1  # Phase 4 one-shot prompt
│   ├── write-codex-fix-prompt.ps1         # Phase 5 fix-only prompt
│   ├── write-final-handoff.ps1            # AI_FINAL_HANDOFF.md generator
│   ├── copy-template-to-service.ps1       # Phase 6 — preview-by-default copier
│   └── validate-template-install.ps1      # Phase 6 — install validator + smoke
└── ai-runs/                               # local-only run artifacts (gitignored)
```

## How to copy this template into a real service repo

The recommended sequence is **always** preview → review → apply → validate.

```powershell
# 1. Preview what would be copied (no files written).
powershell -ExecutionPolicy Bypass -File .\tools\copy-template-to-service.ps1 `
    -TargetRepo D:\path\to\your-service-repo

# 2. If the preview looks correct, apply.
powershell -ExecutionPolicy Bypass -File .\tools\copy-template-to-service.ps1 `
    -TargetRepo D:\path\to\your-service-repo -Apply

# 3. (Optional) Append local-only ignore rules to the target's .gitignore.
powershell -ExecutionPolicy Bypass -File .\tools\copy-template-to-service.ps1 `
    -TargetRepo D:\path\to\your-service-repo -Apply -IncludeLocalGitignoreRules

# 4. Validate the install in the target repo.
powershell -ExecutionPolicy Bypass -File .\tools\validate-template-install.ps1 `
    -TargetRepo D:\path\to\your-service-repo

# 5. Run a Phase 1 smoke test inside the target repo (no Codex, no Claude, no tests).
powershell -ExecutionPolicy Bypass -File .\tools\validate-template-install.ps1 `
    -TargetRepo D:\path\to\your-service-repo -RunSmoke
```

The copy script is **preview-only without `-Apply`**. It refuses to overwrite
existing control documents (`AI_PRODUCT_SPEC.md`, `AI_TASK_QUEUE.md`, etc.)
unless you explicitly pass `-OverwriteControlDocs`. It never copies
`ai-runs/<timestamp>/`, `.claude/`, or `.git/`. It never runs git, never
installs dependencies, and never deletes anything.

For full step-by-step instructions, see `TEMPLATE_USAGE.md`. For a
plain-language checklist, see `SERVICE_ONBOARDING_CHECKLIST.md`.

## What is safe by default

Running `ai-autopilot.ps1` with **no flags** does the following only:

- creates a timestamped folder under `ai-runs/`
- collects a redacted git status / diff snapshot
- runs detection (does **not** install anything, does **not** run tests)
- writes `AI_FINAL_HANDOFF.md`

It does **not** invoke Codex, Claude, tests, commits, pushes, or deploys.

## What requires an explicit opt-in flag

| Behaviour                                | Required flag(s)                                       |
|------------------------------------------|--------------------------------------------------------|
| Run safe local tests                     | `-TestLevel unit` (or `integration`/`e2e`/`all`)        |
| Generate the Codex prompt                | `-Implementer codex`                                    |
| Actually run Codex (one-shot)            | `-Implementer codex -RunImplementer` (and not `-DryRun`)|
| Generate the Claude review prompt        | `-Reviewer claude`                                      |
| Actually run Claude (review-only)        | `-Reviewer claude -RunReviewer` (and not `-DryRun`)     |
| Bounded Codex ↔ Claude fix loop          | All of the above plus `-EnableFixLoop -MaxIterations N` |

`-MaxIterations` is hard-capped at `3` and rejected before any run folder is
created if outside `[1, 3]`.

## What is forbidden in every phase

- `git commit`, `git push`, `git tag`, deploy commands
- Dependency installation (`npm`, `pnpm`, `yarn`, `pip`, `poetry`, `uv`, …)
- `-AutoCommit` (refused with a clear error before any work runs)
- Permissive Codex sandbox flags (`danger-full-access`,
  `--dangerously-bypass-approvals-and-sandbox`, `--full-auto`, yolo, bypass)
- Permissive Claude flags (`--dangerously-skip-permissions`, `acceptEdits`,
  `bypassPermissions`, allowed-edit, allowed-bash)
- Reading or echoing secret material (`.env`, `*.pem`, `*.key`, `*secret*`)
- Modifying files outside the repository root
- Editing files outside the active phase's allowed-files list

**Human approval is required at the end of every run.** The harness will not
approve, commit, push, or deploy on its own. Ever.

## Where to go next

1. **Read** `TEMPLATE_USAGE.md` — the practical user guide.
2. **Read** `SERVICE_ONBOARDING_CHECKLIST.md` — the non-developer checklist.
3. **Skim** `AI_WORKFLOW.md` — phase-by-phase flow and what every artifact means.
4. **Skim** `AGENTS.md` and `CLAUDE.md` — the per-tool guardrails Codex / Claude
   will see when they read this repo.

## License / reuse

This is a personal template. Copy it freely into your own service repos. The
template's safety guarantees only hold if you do not edit the harness scripts,
do not add permissive flags, and do not bypass `-DryRun` / `-RunImplementer` /
`-RunReviewer` gating. If in doubt: read `SERVICE_ONBOARDING_CHECKLIST.md`.
