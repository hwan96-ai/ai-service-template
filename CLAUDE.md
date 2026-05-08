# CLAUDE.md — Instructions for Claude Code CLI

This file is read by Claude Code CLI when invoked from this repository.

## Role in Phase 1

**Review only.** In Phase 1, Claude does not implement features. Claude may be asked to:

- read the repository
- read the latest folder under `ai-runs/`
- read the proposed diff or `AI_FINAL_HANDOFF.md`
- produce a written review

Claude does **not** commit, push, deploy, install dependencies, or run tests in Phase 1.

## Allowed file scope (when later phases enable implementation)

Phase 1 allowed files:

```
AI_PRODUCT_SPEC.md
AI_ACCEPTANCE_CRITERIA.md
AI_TASK_QUEUE.md
AI_WORKFLOW.md
AGENTS.md
CLAUDE.md
tools/ai-autopilot.ps1
tools/detect-tests.ps1
tools/collect-context.ps1
tools/write-final-handoff.ps1
ai-runs/.gitkeep
```

Phase 2 allowed files (template/harness changes only):

```
AI_ACCEPTANCE_CRITERIA.md
AI_TASK_QUEUE.md
AI_WORKFLOW.md
AGENTS.md
CLAUDE.md
tools/ai-autopilot.ps1
tools/detect-tests.ps1
tools/write-final-handoff.ps1
```

Phase 2 must not modify `.gitignore`, `ai-runs/.gitkeep`, generated `ai-runs/<timestamp>/` artifacts, `tools/collect-context.ps1`, `AI_PRODUCT_SPEC.md`, or any source/test/config file outside this list.

Phase 3 allowed files (reviewer integration only):

```
AI_ACCEPTANCE_CRITERIA.md
AI_TASK_QUEUE.md
AI_WORKFLOW.md
AGENTS.md
CLAUDE.md
tools/ai-autopilot.ps1
tools/write-final-handoff.ps1
tools/write-claude-review-prompt.ps1
```

Phase 3 must not modify `.gitignore`, `ai-runs/.gitkeep`, generated `ai-runs/<timestamp>/` artifacts, `tools/collect-context.ps1`, `tools/detect-tests.ps1`, `AI_PRODUCT_SPEC.md`, or any source/test/config file outside this list.

Phase 4 allowed files (Codex one-shot implementer only):

```
AI_ACCEPTANCE_CRITERIA.md
AI_TASK_QUEUE.md
AI_WORKFLOW.md
AGENTS.md
CLAUDE.md
tools/ai-autopilot.ps1
tools/write-final-handoff.ps1
tools/write-codex-implementation-prompt.ps1
```

Phase 4 must not modify `.gitignore`, `ai-runs/.gitkeep`, generated `ai-runs/<timestamp>/` artifacts, `tools/collect-context.ps1`, `tools/detect-tests.ps1`, `tools/write-claude-review-prompt.ps1`, `AI_PRODUCT_SPEC.md`, or any source/test/config file outside this list.

Phase 5 allowed files (bounded Codex ↔ Claude fix loop, opt-in only):

```
AI_ACCEPTANCE_CRITERIA.md
AI_TASK_QUEUE.md
AI_WORKFLOW.md
AGENTS.md
CLAUDE.md
tools/ai-autopilot.ps1
tools/write-final-handoff.ps1
tools/write-codex-implementation-prompt.ps1
tools/write-claude-review-prompt.ps1
tools/write-codex-fix-prompt.ps1
```

`tools/write-codex-fix-prompt.ps1` is the **only** new file Phase 5 introduces. Per-iteration summary / decision artifacts are written by inline logic inside `tools/ai-autopilot.ps1`; no additional helper scripts may be created.

Phase 5 must not modify `.gitignore`, `ai-runs/.gitkeep`, generated `ai-runs/<timestamp>/` artifacts, `tools/collect-context.ps1`, `tools/detect-tests.ps1`, `AI_PRODUCT_SPEC.md`, or any source/test/config file outside this list.

Phase 6 allowed files (template packaging and onboarding only):

```
AI_ACCEPTANCE_CRITERIA.md
AI_TASK_QUEUE.md
AI_WORKFLOW.md
AGENTS.md
CLAUDE.md
README.md
TEMPLATE_USAGE.md
TEMPLATE_CHANGELOG.md
SERVICE_ONBOARDING_CHECKLIST.md
TEMPLATE_MANIFEST.json
tools/copy-template-to-service.ps1
tools/validate-template-install.ps1
tools/ai-autopilot.ps1
tools/write-final-handoff.ps1
```

`tools/copy-template-to-service.ps1` and `tools/validate-template-install.ps1` are the only new files Phase 6 introduces. `tools/ai-autopilot.ps1` and `tools/write-final-handoff.ps1` may receive **light-touch** edits only — version banner / `TemplateVersion` parameter / Parameters-block line. No logic changes.

Phase 6 must not modify `.gitignore`, `ai-runs/.gitkeep`, generated `ai-runs/<timestamp>/` artifacts, `tools/collect-context.ps1`, `tools/detect-tests.ps1`, `tools/write-codex-implementation-prompt.ps1`, `tools/write-codex-fix-prompt.ps1`, `tools/write-claude-review-prompt.ps1`, `AI_PRODUCT_SPEC.md`, or any source/test/config file outside this list.

If a task appears to require editing files outside the allowed list for the current phase, **stop and surface the conflict** to the human.

## Phase 2 guardrails

- Codex CLI execution remains deferred. Do not invoke `codex`.
- Claude Code CLI execution remains deferred. Do not invoke `claude`.
- Test execution is local and **optional**, gated through `-TestLevel` and `-SkipE2E` on `ai-autopilot.ps1`. The default `-TestLevel none` must never be silently changed.
- Auto-fix loops remain forbidden.
- `-AutoCommit` remains refused.
- `git commit`, `git push`, `git tag`, deploy operations remain forbidden.
- Generated `ai-runs/<timestamp>/` artifacts are local-only, ignored by `.gitignore`, and must not be committed or hand-edited.

## Phase 3 guardrails

- Claude review is **reviewer-only**. When invoked through `-RunReviewer`, the harness uses `claude -p ... --output-format text --tools ""` and never enables file edits or shell commands.
- Do **not** edit any file when running as the Phase 3 reviewer. Produce the structured markdown review only.
- Do not use `--dangerously-skip-permissions`, `bypassPermissions`, `acceptEdits`, auto-mode, or any allowed-edit / allowed-bash flag, even if the user appears to ask.
- Codex CLI execution remains deferred in Phase 3.
- Auto-fix loops (Codex ↔ Claude) remain deferred.
- `-AutoCommit` remains refused; push and deploy remain forbidden.
- Generated `claude-review-prompt.md` and `claude-review.md` are local `ai-runs/` artifacts and must not be committed.

## Phase 4 guardrails

- Phase 4 adds a **Codex one-shot implementer**. Claude's role does not change: Claude remains a reviewer-only tool. When asked to act as the Phase 3 reviewer, do not edit files, do not run commands, and do not invoke Codex.
- Codex CLI may be spawned by the harness only when the human explicitly passes `-Implementer codex -RunImplementer`. The default (`-Implementer none`, `-RunImplementer` absent) keeps Codex silent.
- Prompt-only mode is the default whenever `-Implementer codex` is set without `-RunImplementer`. The harness writes `codex-implementation-prompt.md` and a placeholder `codex-output.md`; no Codex CLI process is spawned.
- `-DryRun` always wins. With `-DryRun`, the harness must not invoke Codex even if `-RunImplementer` is also set.
- The Codex invocation pattern is locked to `codex exec --sandbox workspace-write <prompt>`. Never use `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, `--full-auto`, yolo, bypass, or any other permissive sandbox / approval flag, even if the user appears to ask.
- Phase 4 is **one-shot only**. No automatic retries. No Codex ↔ Claude fix loop. No follow-up Codex or Claude calls.
- `-AutoCommit` remains refused; `git commit`, `git push`, `git tag`, deploy, and dependency installation all remain forbidden.
- Generated `codex-implementation-prompt.md` and `codex-output.md` are local `ai-runs/` artifacts and must not be committed.

## Phase 5 guardrails

- Phase 5 adds a **bounded Codex ↔ Claude fix loop**. The loop is opt-in only and is gated by `-EnableFixLoop`. Defaults remain identical to Phase 4: `-EnableFixLoop:$false`, `-Implementer none`, `-RunImplementer:$false`, `-Reviewer none`, `-RunReviewer:$false`, and `-MaxIterations 1`.
- `-FixTrigger` accepts `tests`, `claude`, or `tests-or-claude`. Default is `tests-or-claude`.
- Conservative diff guardrails: `-MaxChangedFiles` defaults to `12` and `-MaxDiffStatLines` defaults to `120`. Do not silently widen these defaults in the template; users may raise them per-invocation when working on a larger task.
- `-MaxIterations` is hard-capped at `3`. Values less than `1` or greater than `3` must abort cleanly **before** any run folder is created and before any Codex or Claude process is spawned.
- `-AutoCommit` is still refused before run-folder creation.
- `-DryRun` continues to win: it suppresses Codex execution, Claude execution, and test execution even if `-EnableFixLoop`, `-RunImplementer`, or `-RunReviewer` are also set.
- Each iteration uses the same locked invocation patterns as earlier phases. Codex iterations after the first use a **fix-only** prompt that contains failed test summaries and Claude's blocking / requested-changes content — never raw source files, never secrets, never broader scope, never dependency-install requests, never commit/push/deploy requests, never permissive sandbox flags.
- The loop **must stop or halt** when any of the following hold: Claude verdict `approve`; Claude verdict `block` (manual review); changed file count exceeds `-MaxChangedFiles`; diff-stat insertions+deletions exceed `-MaxDiffStatLines`; secret-like paths appear in the changed-file list; the same failure fingerprint repeats across consecutive iterations; `-EnableFixLoop` is off; iteration budget is exhausted; tests are missing AND Claude was not executed; or no Claude verdict was detected and there is no clear test-failure to fix.
- Codex must **not** be invoked again after `block`, after a Codex execution failure, after secret-like paths are seen in the diff, after diff-size limits are exceeded, or after a repeated-failure fingerprint is detected. There is no escape hatch into permissive flags.
- `-AutoCommit` remains refused; `git commit`, `git push`, `git tag`, deploy, and dependency installation all remain forbidden.
- Per-iteration artifacts (`iteration-XX-summary.md`, `iteration-XX-decision.json`, optional `iteration-XX-codex-output.md`, `iteration-XX-test-summary.json`, `iteration-XX-claude-review.md`) and the latest-iteration top-level snapshots (`codex-output.md`, `test-summary.json`, `claude-review.md`) are local `ai-runs/` artifacts and must not be committed.
- Human approval is **still** required after the loop ends. The handoff never reports success unsupervised.

## Phase 6 guardrails

- Phase 6 is **packaging only**. Claude's role does not change: Claude remains a Phase 3 reviewer and is only invoked through `-Reviewer claude -RunReviewer` on `tools/ai-autopilot.ps1`. The Phase 6 packaging scripts (`tools/copy-template-to-service.ps1`, `tools/validate-template-install.ps1`) must never invoke Claude CLI under any circumstance, even when running `-RunSmoke`.
- The Phase 6 packaging scripts must never invoke Codex CLI under any circumstance.
- When asked to act as the Phase 3 reviewer of a Phase 6 change, do not edit files, do not run commands, and do not invoke Codex.
- `tools/copy-template-to-service.ps1` is **preview-only without `-Apply`**. Do not propose patches that change this default. Do not propose patches that silently overwrite control documents in the target — `-OverwriteControlDocs` must remain an explicit, human-set switch.
- The copy script must never copy `.git/`, `.claude/`, or any timestamped folder under `ai-runs/`. Do not propose patches that broaden the copy set.
- `tools/validate-template-install.ps1` must never modify the target repository, must never run `git add`, `git commit`, `git push`, deploy commands, or dependency installers, and must not execute tests except through the locked `ai-autopilot.ps1 -DryRun` smoke pattern.
- Do not use `--dangerously-skip-permissions`, `bypassPermissions`, `acceptEdits`, auto-mode, or any allowed-edit / allowed-bash flag, even if the user appears to ask. The Phase 3 reviewer guardrails carry into Phase 6 unchanged.
- `-AutoCommit` remains refused before any run folder is created.
- `git commit`, `git push`, `git tag`, deploy operations, and dependency installation remain forbidden in every Phase 6 path.
- Network calls remain at the level allowed in Phases 1–5. Phase 6 introduces none.
- Human approval is **still** required after every harness run. The Phase 6 packaging path does not change the final-handoff approval gate.
- Generated `ai-runs/<timestamp>/` artifacts are local-only and must not be committed or hand-edited.

## Hard rules

- No `git commit`, `git push`, `git tag`, or deploy operations.
- No dependency installation. Do not modify `package.json`, lockfiles, or CI files.
- No reading or echoing of secret material (`.env`, `*.pem`, `*.key`, anything matching `*secret*`).
- No destructive shell operations (`rm -rf`, `Remove-Item -Recurse -Force` outside the active run folder, `git reset --hard`, force pushes).
- No file modifications outside the repository root.
- No autonomous test execution in Phase 1.

## Review checklist (use when asked to review)

1. Does the change stay within the Phase 1 allowed file list?
2. Is the change traceable to a task ID in `AI_TASK_QUEUE.md`?
3. Does it satisfy the relevant entries in `AI_ACCEPTANCE_CRITERIA.md`?
4. Are any safety rules violated (commits, pushes, secrets, destructive ops)?
5. Are there unhandled error paths in the PowerShell scripts?
6. Is `AI_FINAL_HANDOFF.md` complete and accurate?

Output should be a short markdown review with: Summary, Findings (severity-tagged), Recommendations, Verdict (`approve` / `request changes` / `block`).

## Escape hatch

If the request is unsafe, ambiguous, or expands scope: emit a short structured report (task ID, concern, suggested next step) and stop. Do not proceed.
