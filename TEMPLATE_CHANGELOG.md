# TEMPLATE_CHANGELOG.md

Phase-by-phase changelog for the AI service template. Commit ids reference
this template repository's history.

> **Current template version:** `0.6.10`
>
> Versioning is informational only. Each phase keeps every prior phase's
> safety guarantees intact.

## 0.6.10 - Workflow diagram polish and Korean README

Changed:

- `README.md` Mermaid workflow refined: grouped the preview-first
  stages into a `subgraph`, added `classDef` styling (safe / gate /
  action / human) with a short legend, and kept the diagram compact
  (install → bootstrap → dry-run → human review → optional opt-in
  execution → manual commit). No images or SVG assets added.
- `README.md` install examples and displayed template version pinned
  to `v0.6.10`. Install examples remain preview-first (first block
  without `-Apply`, second block with `-Apply`).
- Added `README_KO.md`, a practical Korean explanation document
  (what it is / is not, when to use it, preview-first install,
  document roles, human-only actions, v0.6.10 usage examples).
  Linked from `README.md` near the top.
- `TEMPLATE_MANIFEST.json` `templateVersion` bumped to `0.6.10` and
  `README_KO.md` added to `requiredFiles`.

Confirmed:

- No runtime behavior change. No script, tool, installer, copy, or
  test behavior changed. No new dependencies, no MCP, no plugin
  system, no generated images or SVG assets.

## 0.6.9 - README visual polish

Changed:

- `README.md` first-screen polish: added latest-release, license,
  PowerShell, and Windows badges next to the existing Pester Safety
  Tests badge; tightened the one-line tagline to highlight
  preview-first, human-in-the-loop, and Codex CLI / Claude Code use;
  reformatted "At A Glance" as a compact table; added a compact
  Mermaid workflow diagram (install → bootstrap → dry-run → human
  review → optional execution → manual commit); install examples
  pinned to `v0.6.9` and remain preview-first.

Confirmed:

- No runtime behavior change. No script, tool, installer, copy, or
  test behavior changed. No new dependencies, no MCP, no plugin
  system, no generated images or SVG assets.

## 0.6.8 - README polish and installer readability refactor

Changed:

- `README.md` reorganized with an "At A Glance" summary, clearer
  preview-first install examples pinned to `v0.6.8`, and explicit
  safety wording (no auto-commit, no auto-push, no deploy, no
  dependency install, no MCP or plugin behavior). AI agents are still
  directed to read `AI_AGENT_BOOTSTRAP.md` first.
- `tools/install-ai-service-template.ps1` refactored into small
  helper functions for readability. Parameters, defaults, preview /
  apply behavior, archive download / extraction, copy-script
  discovery, and named-parameter hashtable splat forwarding are
  unchanged.

Confirmed:

- No behavior change. Same parameters, same preview-first default,
  same `-Apply`, `-IncludeLocalGitignoreRules`, and copy-script
  invocation. No new network calls or dependencies.

## 0.6.7 - Installer argument forwarding fix

Fixed:

- `tools/install-ai-service-template.ps1` now forwards `-TargetRepo`,
  `-Apply`, and `-IncludeLocalGitignoreRules` to
  `tools/copy-template-to-service.ps1` through a named-parameter
  hashtable splat. The previous array-based forwarding could surface as
  "A positional parameter cannot be found that accepts argument
  '<path>'." against a published archive.

Confirmed:

- Preview-first install smoke path remains the default; `-Apply` is
  still required to write files.
- No runtime harness behavior changed. No new git, network, or
  dependency-install side effects were introduced.

## 0.6.5 - Quick-start agent bootstrap support

Added:

- `AI_AGENT_BOOTSTRAP.md` as the first-read entrypoint for AI coding agents.
- `tools/install-ai-service-template.ps1` for a safer GitHub
  download-then-run install pattern.
- Copy support for the bootstrap doc into target repositories.
- Default preservation for existing agent and AI control docs, including
  `AGENTS.md`, `CLAUDE.md`, and `AI_AGENT_BOOTSTRAP.md`.
- Clearer Claude Code entrypoint guidance through uppercase `CLAUDE.md`.

## 0.6.4 — Patch release metadata alignment

Updated:

- Preserved target `README.md` during template copy.
- Dogfooding in `auto_resume` confirmed template install, smoke validation,
  and prompt-only Codex flow.
- Aligned internal template version metadata with `0.6.4`.

## Public release hardening

After the 0.6.0 packaging work, this repository received public-release
cleanup: repository hygiene, MIT licensing, a stronger README front door,
a sample final handoff, reusable public template docs, `SECURITY.md`, safety
self-tests, and a concise comparison section. These changes are documentation,
metadata, and test visibility work; they do not change harness runtime
behaviour.

## 0.6.0 — Phase 6: packaging and reuse support

Commit id: `1e705f8 chore: add Phase 6 template packaging and onboarding support`.

Added:

- `README.md` — practical template overview, who/what, how to copy, safety
  summary.
- `TEMPLATE_USAGE.md` — main user guide: quick start, safe progression,
  example commands, safety, troubleshooting.
- `SERVICE_ONBOARDING_CHECKLIST.md` — non-developer checklist for applying
  the template to a real service repo.
- `TEMPLATE_CHANGELOG.md` — this file.
- `TEMPLATE_MANIFEST.json` — machine-readable manifest of required files,
  tool files, local artifact patterns, forbidden behaviours, and the
  recommended safe-progression command list.
- `tools/copy-template-to-service.ps1` — preview-by-default copier; only
  copies files listed in `TEMPLATE_MANIFEST.json`; refuses to overwrite
  control documents unless `-OverwriteControlDocs` is explicitly passed;
  never copies `ai-runs/<timestamp>/`, `.claude/`, or `.git/`; never invokes
  git, never installs dependencies, never deletes files.
- `tools/validate-template-install.ps1` — install validator with a
  `-RunSmoke` switch that runs `ai-autopilot.ps1 -DryRun -Goal "template
  install smoke test"` without invoking Codex or Claude; checks required
  control documents, tool files, `ai-runs/.gitkeep`, `.gitignore` rules
  (warn-only), git repo state, and PowerShell parser-tokenises key scripts.

Updated (light-touch only):

- `AI_WORKFLOW.md` — added Phase 6 "Packaging and reuse" section.
- `AI_ACCEPTANCE_CRITERIA.md` — added Phase 6 acceptance criteria block.
- `AI_TASK_QUEUE.md` — added `T-006` row.
- `AGENTS.md` — added Phase 6 allowed-files list and Phase 6 guardrails.
- `CLAUDE.md` — added Phase 6 allowed-files list and Phase 6 guardrails.
- `tools/ai-autopilot.ps1` — version banner reads `Phase 6`; `goal.txt`
  records `TemplateVersion: 0.6.0`. No logic changes; Codex / Claude / fix
  loop behaviour is unchanged.
- `tools/write-final-handoff.ps1` — accepts an optional `-TemplateVersion`
  parameter (default `0.6.0`) and prints it in the Parameters block;
  Autopilot Phase line reads `Phase 6`. No logic changes.

Phase 6 deliberately does **not** add or change any Codex, Claude, or
fix-loop behaviour. It only makes the template safe to **reuse** across
service repos.

## 0.5.0 — Phase 5: bounded Codex ↔ Claude fix loop scaffolding

Commit id: `bad710b chore: add Phase 5 bounded fix loop scaffolding`.

Added:

- `tools/write-codex-fix-prompt.ps1` — fix-only Codex prompt for iterations
  2+. Embeds only failed-test summaries, parsed Claude blocking /
  requested-changes excerpts, and summary git context. No raw diffs, no
  source contents, no secrets, no broader scope.
- `-EnableFixLoop`, `-FixTrigger {tests | claude | tests-or-claude}`,
  `-MaxChangedFiles 12`, `-MaxDiffStatLines 120`, and `-MaxIterations` cap
  of `3`. All defaults are off / conservative.
- Per-iteration artifacts (`iteration-XX-summary.md`,
  `iteration-XX-decision.json`, optional `iteration-XX-codex-output.md`,
  `iteration-XX-test-summary.json`, `iteration-XX-claude-review.md`) and a
  top-level `loop-summary.json`.

Stop conditions: Claude verdict `approve` → stop; verdict `block` → halt;
changed-file count exceeds `-MaxChangedFiles` → halt; diff insertions+
deletions exceed `-MaxDiffStatLines` → halt; secret-like paths appear in
the changed-file list → halt; same failure fingerprint repeats across
consecutive iterations → halt; iteration budget exhausted → stop.

Auto-commit, auto-push, auto-deploy, auto-tag, auto-merge, and dependency
installation remain forbidden in every iteration. Codex sandbox stays
locked at `workspace-write`; no permissive flags are ever introduced.

## 0.4.0 — Phase 4: Codex one-shot implementation support

Commit id: `645dc4a chore: add Phase 4 Codex one-shot implementation support`.

Added:

- `tools/write-codex-implementation-prompt.ps1` — generates
  `codex-implementation-prompt.md` summarising the active goal / task,
  acceptance criteria, allowed files for the current phase, and a
  controlled context bundle (no raw diffs, no source contents, no secrets).
- `-Implementer codex`, `-RunImplementer`, `-CodexCommand`, `-CodexSandbox`,
  `-CodexRunMode` switches.
- One-shot only: when `-RunImplementer` is set (and `-DryRun` is not), the
  harness invokes `codex exec --sandbox workspace-write <prompt>` exactly
  once. No automatic retry. No follow-up Codex or Claude calls.
- Permissive Codex flags (`danger-full-access`,
  `--dangerously-bypass-approvals-and-sandbox`, `--full-auto`, yolo,
  bypass) are never used.
- Auto-commit, push, deploy, and dependency installation remain forbidden.

## 0.3.0 — Phase 3: Claude review prompt support

Commit id: `5b02bef chore: add Phase 3 Claude review prompt support`.

Added:

- `tools/write-claude-review-prompt.ps1` — generates
  `claude-review-prompt.md` requesting a structured response with
  `Verdict`, `Summary`, `Blocking Issues`, `Non-blocking Issues`,
  `Test Assessment`, `Safety Assessment`, `Suggested Fix Prompt For Codex`,
  `Approval Readiness`, and `Suggested Commit Message` sections.
- `-Reviewer claude`, `-RunReviewer`, `-ClaudeCommand`, `-ClaudeReviewMode`
  switches.
- Reviewer-only execution: even with `-RunReviewer`, the harness uses
  `claude -p <prompt> --output-format text --tools ""`. Permissive flags
  (`--dangerously-skip-permissions`, `acceptEdits`, `bypassPermissions`,
  allowed-edit, allowed-bash) are never used. No alternative permissive
  modes are attempted on failure.
- The handoff Result line is verdict-aware (`approve` / `request_changes` /
  `block`).

## 0.2.0 — Phase 2: test detection and execution reporting

Commit id: `4a5c9ce chore: add Phase 2 test detection and execution reporting`.

Added:

- `tools/detect-tests.ps1` — writes `detected-tests.md` and structured
  `detected-tests.json` (with `repoRoot`, `detectedStacks`, `testCommands`,
  `warnings`, `noTestsFound`). Detection covers Node (npm/pnpm), Python
  (`pyproject.toml`/`pytest.ini`/`requirements.txt`/`tests/`), Playwright,
  and split repos (`frontend/`, `backend/`).
- `-TestLevel none|unit|integration|e2e|all` and `-SkipE2E` switches on
  `ai-autopilot.ps1`. The default `-TestLevel none` keeps execution off.
- Per-command denylist for installs (`npm install`, `pip install`, …),
  destructive ops (`rm -rf`, `Remove-Item -Recurse`, `git reset --hard`,
  `git clean`), git mutations (`git push`, `git commit`), and `deploy`.
- `test-output.txt` and `test-summary.json` are always produced, even when
  no commands run.
- Run folders gained millisecond precision (`yyyyMMdd-HHmmss-fff`) and
  optional collision suffixes; existing folders are never overwritten.

## 0.1.0 — Phase 1: harness foundation

Commit id: `eaaba00 chore: add safe local AI automation harness foundation`.

Added:

- Control documents at the repo root: `AI_PRODUCT_SPEC.md`,
  `AI_ACCEPTANCE_CRITERIA.md`, `AI_TASK_QUEUE.md`, `AI_WORKFLOW.md`,
  `AGENTS.md`, `CLAUDE.md`.
- `tools/ai-autopilot.ps1`, `tools/collect-context.ps1`,
  `tools/write-final-handoff.ps1`, and an early `tools/detect-tests.ps1`
  stub.
- `ai-runs/.gitkeep` plus `.gitignore` rules ignoring `ai-runs/*` while
  preserving the sentinel.
- Hard refusal of `-AutoCommit`. No git commit, push, deploy, or
  dependency installation is performed in any phase.
