# Project Overview

## When To Use This

Use this document when you need the high-level purpose, boundaries, and
non-goals of this repository before changing documentation, scripts, or tests.

## What This Repository Is

`ai-service-template` is a Windows/PowerShell, preview-first AI coding safety
harness for Codex CLI, Claude Code CLI, and similar local coding-agent
workflows. It provides control documents, PowerShell scripts, prompt artifacts,
test detection, optional local checks, and final handoff files.

The repository is a reusable template. Preserve generality and avoid
project-specific claims unless the current repository evidence supports them.

## What This Repository Is Not

This repository is not a product runtime, SaaS framework, hosted AI service, MCP
runtime, plugin runtime, or cross-platform application scaffold. Do not infer
application behavior, deployment behavior, user data models, backend services,
or frontend frameworks from this harness.

## Primary Workflow

The smallest useful workflow is preview-first:

1. Copy or install the harness into a target service repository.
2. Run dry-run or prompt-only commands.
3. Inspect generated local artifacts under `ai-runs/`.
4. Let a human decide whether to proceed with real Codex, Claude, tests, or
   manual git actions.

## Durable Safety Stance

The harness documents and scripts emphasize no automatic dependency
installation, commit, push, deploy, tag, merge, or release. Generated
`ai-runs/` artifacts are local-only and must not be committed.
