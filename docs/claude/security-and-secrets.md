# Security And Secrets

## When To Use This

Use this document before collecting context, writing prompts, reviewing diffs,
or preparing any public-facing summary.

## Non-Disclosure Rules

Agents must not read, print, summarize, copy, move, or expose:

- Secrets
- Credentials
- Template deployment tokens
- Private customer details
- Internal URLs
- Proprietary implementation notes
- Non-public business information

If a secret-like path appears in a diff or task, stop and report the concern
without opening the file contents.

## Prompt And Artifact Hygiene

Prompt artifacts and final handoffs should use summarized context. Do not
include raw secret material, environment-specific credentials, private customer
data, or sensitive operational details.

Generated `ai-runs/` folders are local artifacts and must not be committed.
Local Claude state under `.claude/` is also not source-control intent.

## Dependency And Execution Safety

Do not install dependencies, run deploy commands, use permissive sandbox flags,
or bypass approval and sandbox rules. If validation requires a tool that is not
already available, report the missing tool and use a safer check where possible.
