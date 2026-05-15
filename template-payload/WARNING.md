# WARNING — Placeholder Payload Only

The files in this directory are **placeholders** that downstream services
copy and customize for their own context. They are not the actual harness
rules; the harness rules live in `.claude/rules/` at the repo root.

## Do NOT commit real secrets, PII, or production data here

- No API keys, tokens, passwords, or session credentials
- No customer data, internal hostnames, IP addresses, or SQL fragments
- No private endpoints, internal URLs, or credentials in example commands
- No production database dumps, log excerpts, or stack traces from real users

If you accidentally commit any of the above:

1. Rotate the credential immediately at the provider.
2. Remove from git history (`git filter-repo` or BFG Repo-Cleaner).
3. Force-push the cleaned history.
4. Audit the provider's access logs for the exposure window.

## What goes here instead

- Generic placeholder structures showing the **shape** of the data
- `<TODO: customer fills this in>` markers
- Sanitized examples (`api.example.com`, `user@example.com`, `${API_KEY}`)
- References to documents the customer will own (e.g., "see your team's
  internal threat-model doc")

## Why this matters

This template is meant to be `git clone`'d by other teams. Anything in
`template-payload/` becomes the seed for someone else's service repo.
A leaked secret here propagates with every fork.

The CI `rules-integrity` workflow does not scan for secrets in this
directory — that is intentional, because there should not be any. Run
`gitleaks` or `truffleHog` locally before pushing if you are unsure.
