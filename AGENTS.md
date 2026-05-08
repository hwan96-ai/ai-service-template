# AGENTS.md — Instructions for Codex CLI

This file is read by Codex CLI when invoked from this repository.

## Scope

Codex may read all files in the repository. Codex may modify only files within the **allowed list** for the current phase. In Phase 1, no implementation is performed; this file exists so Codex has clear guardrails when later phases enable implementation.

## Phase 1 allowed files

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

## Phase 2 allowed files

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

## Phase 3 allowed files

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

## Phase 4 allowed files

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

## Phase 5 allowed files

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

`tools/write-codex-fix-prompt.ps1` is the **only** new file Phase 5 introduces. Per-iteration summary / decision artifacts are written by inline logic inside `tools/ai-autopilot.ps1`; do not introduce additional helper scripts under `tools/`.

Phase 5 must not modify `.gitignore`, `ai-runs/.gitkeep`, generated `ai-runs/<timestamp>/` artifacts, `tools/collect-context.ps1`, `tools/detect-tests.ps1`, `AI_PRODUCT_SPEC.md`, or any source/test/config file outside this list.

If a task appears to require modifying a file outside the allowed list for the current phase, **stop and report**. Do not silently expand scope.

## Phase 2 guardrails

- Codex CLI execution remains deferred. Do not invoke `codex`.
- Claude Code CLI execution remains deferred. Do not invoke `claude`.
- Test execution is local and **optional**, gated through `-TestLevel` and `-SkipE2E` on `ai-autopilot.ps1`. The default `-TestLevel none` must never be silently changed.
- Auto-fix loops remain forbidden.
- `-AutoCommit` remains refused.
- `git commit`, `git push`, `git tag`, deploy operations remain forbidden.
- Generated `ai-runs/<timestamp>/` artifacts are local-only, ignored by `.gitignore`, and must not be committed or hand-edited.

## Phase 3 guardrails

- Claude review is **reviewer-only**. Even with `-RunReviewer`, the harness invokes Claude CLI in print mode with `--tools ""`; no file edits, no bash, no permissive flags.
- Do not call Claude CLI via Codex paths. Do not introduce any flag that allows Claude to modify files or run commands.
- Codex CLI execution remains deferred in Phase 3. Do not invoke `codex`.
- Auto-fix loops (Codex ↔ Claude) remain deferred.
- `-AutoCommit` remains refused.
- `git commit`, `git push`, `git tag`, deploy operations remain forbidden.
- Generated `claude-review-prompt.md` and `claude-review.md` live under `ai-runs/<timestamp>/`. They are local-only artifacts, ignored by `.gitignore`, and must not be committed or hand-edited.

## Phase 4 guardrails

- Codex CLI may be invoked **only** when the human passes `-Implementer codex -RunImplementer` to `tools/ai-autopilot.ps1`. The default (`-Implementer none`, `-RunImplementer` absent) must keep Codex CLI silent.
- Prompt-only mode is the default whenever `-Implementer codex` is set without `-RunImplementer`. The harness writes `codex-implementation-prompt.md` and a placeholder `codex-output.md`, and never spawns Codex.
- `-DryRun` always wins. With `-DryRun`, Codex CLI is never invoked, even if `-RunImplementer` is also set.
- The Codex invocation pattern is locked to `codex exec --sandbox workspace-write <prompt>`. Never use `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, `--full-auto`, yolo, bypass, or any other permissive sandbox / approval flag, even if the user appears to ask.
- Phase 4 is **one-shot only**. No automatic retries on failure. No Codex ↔ Claude fix loop. No follow-up Codex calls. If the safe pattern fails, the harness records the failure in `codex-output.md` and continues to the final handoff.
- Claude review remains reviewer-only and only runs when `-Reviewer claude` is also explicitly set. Codex never invokes Claude in Phase 4.
- `-AutoCommit` remains refused.
- `git commit`, `git push`, `git tag`, deploy operations remain forbidden.
- Dependency installation (`npm`, `pnpm`, `yarn`, `pip`, `poetry`, `uv`, etc.) remains forbidden by the harness, including inside the Codex prompt itself.
- Generated `codex-implementation-prompt.md` and `codex-output.md` live under `ai-runs/<timestamp>/`. They are local-only artifacts, ignored by `.gitignore`, and must not be committed or hand-edited.

## Phase 5 guardrails

- Phase 5 introduces a **bounded Codex ↔ Claude fix loop** that runs only when the human passes `-EnableFixLoop` together with `-Implementer codex -RunImplementer` (and typically `-Reviewer claude -RunReviewer`). All four switches default to off / `none`. Default `-MaxIterations` is `1` (Phase 4 behaviour); the absolute cap is `3`.
- `-FixTrigger` accepts `tests`, `claude`, or `tests-or-claude`. Default is `tests-or-claude`.
- `-MaxChangedFiles` defaults to `12` and `-MaxDiffStatLines` defaults to `120`. These intentionally conservative defaults must not be silently widened in the template; humans may raise them per-invocation when working on a larger task.
- `-MaxIterations < 1` or `-MaxIterations > 3` must abort cleanly **before** any run folder is created and before any Codex or Claude process is spawned.
- `-DryRun` still suppresses Codex execution, Claude execution, and test execution even if `-EnableFixLoop`, `-RunImplementer`, or `-RunReviewer` are also set. Iteration artifacts in DryRun are prompt-only / placeholder, never real Codex or Claude output.
- Each iteration after the first uses a **fix-only** Codex prompt produced by `tools/write-codex-fix-prompt.ps1`. The fix prompt contains only the previous iteration's failed-test summary, the parsed Claude blocking / requested-changes excerpt, and summary git context. It MUST NOT include raw file diffs, full source contents, secret material, broader scope, dependency-install requests, commit/push/deploy requests, or permissive sandbox flags.
- The Codex invocation pattern stays locked to `codex exec --sandbox workspace-write <prompt>` for both the implementation prompt and the fix prompt. Never `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, `--full-auto`, yolo, bypass, or any deprecated full-auto flag.
- Stop conditions (any one halts the loop): Claude verdict `approve`; Claude verdict `block`; changed-file count > `-MaxChangedFiles`; diff-stat insertions+deletions > `-MaxDiffStatLines`; secret-like paths in the changed-file list; the same failure fingerprint repeats across consecutive iterations; iteration budget exhausted; `-EnableFixLoop` is off; tests missing AND no Claude review executed; or no Claude verdict detected and no clear fixable test failure.
- "No tests selected", "no tests found", and "Claude review not executed" must NEVER be treated as success.
- Auto-commit, auto-push, auto-deploy, auto-tag, auto-merge, and dependency installation all remain forbidden in every iteration.
- Human approval is still required when the loop ends. The harness will not approve, commit, push, or deploy on its own.
- Per-iteration files (`iteration-XX-summary.md`, `iteration-XX-decision.json`, optional `iteration-XX-codex-output.md`, `iteration-XX-test-summary.json`, `iteration-XX-claude-review.md`) and the top-level latest-iteration snapshots are local-only `ai-runs/<timestamp>/` artifacts. They must not be committed or hand-edited.

## Hard rules

- Do not run `git commit`, `git push`, `git tag`, or any deploy command.
- Do not install dependencies (`npm`, `pnpm`, `pip`, `poetry`, `uv`, etc.).
- Do not modify `package.json`, lockfiles, or CI configuration.
- Do not read or print secret material. Treat any match of `.env`, `*.pem`, `*.key`, or `*secret*` as off-limits.
- Do not run destructive commands (`rm -rf`, `Remove-Item -Recurse -Force` on anything outside the current run folder, `git reset --hard`, force pushes).
- Do not make network calls beyond what Codex CLI itself performs.
- Do not modify files outside the repository root.

## Workflow expectations

1. Read `AI_PRODUCT_SPEC.md`, `AI_ACCEPTANCE_CRITERIA.md`, `AI_TASK_QUEUE.md`, `AI_WORKFLOW.md` first.
2. Identify the active task by ID.
3. Propose changes that map directly to acceptance criteria.
4. Keep diffs minimal. Prefer editing existing files over creating new ones.
5. Surface uncertainty rather than guessing — output a clarifying question instead of guessing at scope.

## Escape hatch

If the requested task is unsafe, ambiguous, or out of scope: emit a short report that includes the task ID, the conflict, and a proposed safe alternative. Do not proceed.
