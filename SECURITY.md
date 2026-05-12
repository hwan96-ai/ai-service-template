# Security And Threat Model

This project is a local safety harness around Codex CLI and Claude Code CLI. It is
not a security boundary for a compromised machine, a malicious local user, or a
compromised upstream CLI. Its guardrails are designed to reduce accidental damage
during normal local AI-assisted development.

## What This Harness Protects Against

- Accidental commits, pushes, tags, merges, or deploys by the harness.
- Accidental dependency installs during harness runs.
- Permissive Codex sandbox flags such as `danger-full-access`, bypass, yolo, or
  full-auto modes.
- Hidden agent execution: dry-run and prompt-only modes are the default, and real
  Codex or Claude execution requires explicit run flags.
- Unbounded Codex and Claude fix loops through explicit loop opt-in, iteration
  caps, changed-file caps, diff-size caps, and stop conditions.
- Generated run artifacts being committed by keeping timestamped `ai-runs/`
  output local-only and ignored by git.
- Accidental secret exposure through collected context by avoiding secret-like
  files and raw secret material in prompts and summaries.
- Secret-like paths in git status, diff name, and diff stat artifacts are
  redacted before those artifacts are embedded into prompts or handoffs.

These are guardrails, not absolute guarantees. A human should still review the
goal text, generated prompts, diffs, test output, and final handoff before
continuing.

## What This Harness Does Not Protect Against

- Malicious local users who can edit scripts, prompts, git config, or shell
  aliases.
- Compromised Codex CLI or Claude Code CLI binaries.
- A compromised operating system, shell, PowerShell profile, terminal, or PATH.
- Unsafe manual commands run outside the harness.
- Secrets already committed to the repository or intentionally included in task
  descriptions.
- Unsafe, overly broad, or secret-bearing task descriptions written by the
  human.
- Trusted repository test scripts or wrappers that perform side effects
  internally after their wrapper command text passes the harness deny-list.
- Sensitive values printed by local checks, Codex, or Claude. Timestamped
  `ai-runs/` artifacts may contain sensitive tool output if a trusted command or
  CLI prints it.
- Upstream Codex CLI or Claude Code CLI behavior changes that alter command
  semantics.

## Safety Model

- `-DryRun` and prompt-only flows are the safest default path.
- Real Codex execution requires explicit opt-in with implementer run flags.
- Real Claude review requires explicit opt-in with reviewer run flags.
- The harness does not auto-commit, auto-push, auto-deploy, auto-install,
  auto-tag, or auto-merge.
- Codex execution is locked to the `workspace-write` sandbox pattern.
- Claude is used in review-only mode with tools disabled.
- The fix loop is opt-in and bounded by iteration, changed-file, and diff-size
  limits.
- Generated `ai-runs/` artifacts are local-only run output, not release assets.
- Every run ends with a human-reviewable `AI_FINAL_HANDOFF.md` before any commit
  decision.

## Assumptions

- You trust the local repository checkout enough to run its PowerShell scripts.
- You review script changes before updating the harness in a service repo.
- Codex CLI and Claude Code CLI are installed from sources you trust and are kept
  current enough for the documented flags to behave as expected.
- After updating Codex CLI or Claude Code CLI, you re-check compatibility of the
  documented sandbox and review-only invocation patterns before relying on real
  execution.
- Selected local checks come from a trusted repository. The harness deny-lists
  wrapper command text, but it does not sandbox the internals of those scripts.
- Secrets are stored outside the repository and are not pasted into goals,
  prompts, task queues, or product specs.
- A human remains responsible for reviewing diffs, test results, AI output,
  Claude review results, and the final handoff.

## Optional Secret Scanning

Secret scanning is optional but recommended before publishing this repository
or accepting pull requests. A minimal `.gitleaks.toml` is included at the
repository root for use with [gitleaks](https://github.com/gitleaks/gitleaks).
The harness does not install gitleaks and does not run it for you.

If you have gitleaks installed locally, you can run a scan from the repo root,
for example:

```powershell
gitleaks detect --source . --config .gitleaks.toml --redact
```

Notes:

- The bundled config extends the gitleaks default ruleset and only allowlists
  local artifact directories (`ai-runs/`, `.claude/`). Real secret-bearing
  paths such as `.env`, `*.pem`, `*.key`, and `*secret*` are intentionally not
  allowlisted.
- Generated `ai-runs/` artifacts are local-only and remain ignored by git.
  They may still contain sensitive tool output and should not be committed or
  shared without review.
- Secret scanning is a backstop, not a replacement for careful human review of
  goals, prompts, diffs, test output, and the final handoff. A clean gitleaks
  run does not prove the repository is free of secrets.

## If You Find A Safety Issue

Open a public issue if the report does not contain secrets. Include the command
you ran, the expected guardrail, the observed behavior, and relevant sanitized
output.

If the issue involves a secret, private path, token, credential, or sensitive
repository detail, do not paste it into a public issue. Redact the sensitive
material first, or report only the minimal reproduction needed to understand the
guardrail failure.
Do not run this harness on repositories you do not trust.
