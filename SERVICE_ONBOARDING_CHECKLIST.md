# SERVICE_ONBOARDING_CHECKLIST.md

Use this checklist when you are bringing the AI service template into a real
service repository for the first time. It is intentionally written for someone
who is **not comfortable reading code deeply**. Every step has a copy-paste
command. Tick boxes as you go.

> **Template version:** `0.6.0`
>
> **Reading order:** `README.md` → `TEMPLATE_USAGE.md` → this file.

---

## 1. Before copying

Before you touch the target repo, confirm all of the following:

- [ ] You have a backup of the target service repo, or you can `git stash`
      / commit your in-progress work in that repo. The copy script does not
      delete files, but you should still have a clean baseline.
- [ ] The target repo is a real git repository (it has a `.git/` folder).
- [ ] You are on a branch you are comfortable adding files to. Do **not** copy
      the template directly onto `main` / `master`. Create a branch first.
- [ ] You know the absolute path to the target repo (for example
      `D:\path\to\your-service-repo`).
- [ ] You have read `README.md` and `TEMPLATE_USAGE.md` once. You do not need
      to memorise them — they are the reference.
- [ ] You understand that the copy script is **preview-only by default** and
      will not write anything until you pass `-Apply`.

---

## 2. Files the template will copy

The exact list lives in `TEMPLATE_MANIFEST.json`. At a glance, the copy
script will place the following files in the target repo (relative paths):

- `AI_PRODUCT_SPEC.md`
- `AI_ACCEPTANCE_CRITERIA.md`
- `AI_TASK_QUEUE.md`
- `AI_WORKFLOW.md`
- `AGENTS.md`
- `CLAUDE.md`
- `README.md` *(template README — overwrites only if `-OverwriteControlDocs`)*
- `TEMPLATE_USAGE.md`
- `TEMPLATE_CHANGELOG.md`
- `SERVICE_ONBOARDING_CHECKLIST.md`
- `TEMPLATE_MANIFEST.json`
- `tools/ai-autopilot.ps1`
- `tools/collect-context.ps1`
- `tools/detect-tests.ps1`
- `tools/write-claude-review-prompt.ps1`
- `tools/write-codex-implementation-prompt.ps1`
- `tools/write-codex-fix-prompt.ps1`
- `tools/write-final-handoff.ps1`
- `tools/copy-template-to-service.ps1`
- `tools/validate-template-install.ps1`
- `ai-runs/.gitkeep` *(folder sentinel)*

The copy script will **never** copy:

- [ ] `.git/`
- [ ] `.claude/`
- [ ] Any timestamped folder inside `ai-runs/` (`ai-runs/<yyyyMMdd-HHmmss>/`)
- [ ] Any file outside the manifest

---

## 3. Files you must customise after copying

After the copy completes, you must edit two files in the target repo before
running the harness against real work:

- [ ] `AI_PRODUCT_SPEC.md` — describe what the service is, who uses it, what
      is in scope for the next iteration, what is out of scope, and how you
      will know "done".
- [ ] `AI_TASK_QUEUE.md` — add at least one task ID (e.g. `T-101`) that
      describes the change you want done first.

Optional but recommended:

- [ ] Skim `AI_WORKFLOW.md` once so you know which artifact to read after
      each run.

You should **not** edit:

- [ ] `tools/*.ps1` — these are the safety-checked harness scripts.
- [ ] `AGENTS.md` and `CLAUDE.md` — these tell Codex / Claude what is allowed
      per phase. Editing them weakens guardrails.
- [ ] `TEMPLATE_MANIFEST.json` — modifying it in the target repo can confuse
      the validator.

---

## 4. First smoke tests (no Codex, no Claude, no real tests)

Run these three commands in the target repo, in order. Each one should finish
cleanly and print a final `NO commit, NO push, NO deploy` notice.

- [ ] `powershell -ExecutionPolicy Bypass -File .\tools\validate-template-install.ps1 -TargetRepo .`

      Expected: prints a list of `pass` checks and exits with code `0`. If
      it warns about `.gitignore` rules, see TEMPLATE_USAGE.md → Troubleshooting.

- [ ] `powershell -ExecutionPolicy Bypass -File .\tools\validate-template-install.ps1 -TargetRepo . -RunSmoke`

      Expected: same as above plus a `-DryRun` smoke run of `ai-autopilot.ps1`.
      Creates exactly **one** new folder under `ai-runs/`. Exits with code `0`.
      Does not invoke Codex or Claude.

- [ ] `powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -DryRun -Goal "smoke"`

      Expected: a fresh `ai-runs/<timestamp>/` folder containing
      `goal.txt`, `git-status.txt`, `git-diff-stat.txt`, `git-diff-names.txt`,
      `detected-tests.md`, `detected-tests.json`, `test-output.txt`,
      `test-summary.json`, and `AI_FINAL_HANDOFF.md`.

If any of those three steps fails: **stop here**. Read the error message and
the most recent `AI_FINAL_HANDOFF.md`. Do not proceed to Codex / Claude
verification yet.

---

## 5. Codex CLI verification (optional, only if you plan to use Codex)

Skip this section if you do not have Codex CLI installed.

- [ ] Confirm `codex --version` runs.
- [ ] Generate the Codex prompt **without** running Codex:

      `powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -Implementer codex -DryRun -Goal "Codex prompt only"`

      Expected: a `codex-implementation-prompt.md` file is created. A
      placeholder `codex-output.md` says `Codex implementation was requested
      but not executed.`. Codex CLI is **not** spawned.

- [ ] Hand the prompt file to Codex CLI yourself once, manually, to confirm
      Codex understands and respects the prompt. Read its output. Do **not**
      let it commit, push, or install dependencies.

- [ ] Only after the manual run looks safe: try `-RunImplementer`:

      `powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -Implementer codex -RunImplementer -TestLevel unit -Goal "one-shot"`

      Expected: the harness invokes `codex exec --sandbox workspace-write`
      exactly once. `codex-output.md` captures stdout, stderr, and exit code.
      The harness does **not** retry. The harness does **not** commit.

If Codex's output suggests broadening scope, installing dependencies,
committing, pushing, or deploying: stop. Do not run `-EnableFixLoop` on this
service repo until the manual one-shot path is reliably safe.

---

## 6. Claude CLI verification (optional, only if you plan to use Claude review)

Skip this section if you do not have Claude Code CLI installed.

- [ ] Confirm `claude --version` runs.
- [ ] Generate the Claude review prompt **without** running Claude:

      `powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -Reviewer claude -DryRun -Goal "Claude prompt only"`

      Expected: `claude-review-prompt.md` is created. `claude-review.md`
      placeholder says `Claude review was requested but not executed.`.
      Claude CLI is **not** spawned.

- [ ] Confirm your local Claude CLI accepts `-p`, `--output-format text`,
      and `--tools ""` (the locked review-only invocation pattern).

- [ ] Try `-RunReviewer`:

      `powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -Reviewer claude -RunReviewer -TestLevel unit -Goal "Claude review"`

      Expected: the harness runs Claude in **review-only** mode. The output
      contains a `Verdict:` line. The Result line in `AI_FINAL_HANDOFF.md`
      surfaces the verdict.

If your Claude CLI rejects the locked invocation pattern, the harness writes
`Automatic Claude review could not be executed safely` and continues. **Do
not patch the harness to use `--dangerously-skip-permissions` or any
allowed-edit / allowed-bash flag.** Run Claude manually instead.

---

## 7. Safe first real run

Only after sections 4–6 succeed. From the target service repo:

- [ ] Pick exactly one task in `AI_TASK_QUEUE.md`. Set its status to `doing`.
- [ ] Run the one-shot Codex + Claude flow **without** the fix loop:

      `powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -Implementer codex -RunImplementer -Reviewer claude -RunReviewer -TestLevel unit -Goal "T-101 first real run"`

- [ ] Read `ai-runs/<timestamp>/AI_FINAL_HANDOFF.md` from top to bottom.
- [ ] Read `claude-review.md`. Confirm the verdict.
- [ ] Read `git status` by hand (`git status`). Confirm only files in the
      task scope changed.
- [ ] Decide as a human whether to commit, request changes, or roll back.

The fix loop (`-EnableFixLoop -MaxIterations 2`) is only safe to enable
**after** the manual one-shot path is repeatably clean for that repo.

---

## 8. What not to commit

Never commit any of the following:

- [ ] `ai-runs/<timestamp>/` — any timestamped folder. Keep only
      `ai-runs/.gitkeep`.
- [ ] `.claude/` — local Claude Code CLI state.
- [ ] `.env`, `*.pem`, `*.key`, anything matching `*secret*` — secrets.
- [ ] Anything inside the active run folder while a run is in progress.

If `git status` shows an `ai-runs/<timestamp>/` folder as untracked, your
target repo's `.gitignore` is missing the standard rules. Re-run the copy
script with `-Apply -IncludeLocalGitignoreRules`, or add the following two
lines manually:

```
ai-runs/*
!ai-runs/.gitkeep
.claude/
```

---

## 9. When to stop and ask for help

Stop and get help (don't push through) when any of the following happen:

- [ ] `validate-template-install.ps1` exits non-zero and you cannot tell
      from the output which file is missing.
- [ ] The harness creates an `ai-runs/<timestamp>/` folder but
      `AI_FINAL_HANDOFF.md` is missing.
- [ ] Codex output suggests committing, pushing, deploying, installing
      dependencies, or editing files outside the active task scope.
- [ ] Claude review verdict is `block`. (`block` is a hard halt — do not
      "try again" with the fix loop.)
- [ ] The fix loop halts with `secret-like-paths-in-diff`. Do not bypass
      this check. Open the diff yourself.
- [ ] The fix loop halts with `repeated-failure-fingerprint`. Codex is
      stuck. Do not raise `-MaxIterations`.
- [ ] The fix loop halts with `max-changed-files-exceeded` or
      `max-diff-stat-exceeded` and you do not understand why the diff is
      that large.
- [ ] You see any sign that the harness scripts have been modified.
      Compare against the source template and restore from version control.

Default rule: when in doubt, stop and read `AI_FINAL_HANDOFF.md`. The
template is built around the assumption that you, the human, make the
decision at the end.
