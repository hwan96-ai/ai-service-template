[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RunFolder,
    [string]$Goal = '',
    [string]$TaskId = '',
    [string]$TestLevel = 'none',
    [switch]$SkipE2E,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $RunFolder)) {
    throw "write-codex-implementation-prompt: run folder does not exist: $RunFolder"
}

# Resolve repo root from run folder (run folder lives at <repo>/ai-runs/<ts>).
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $RunFolder '..\..')).ProviderPath

function Read-Artifact {
    param([string]$Path, [int]$MaxLines = 0)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $content = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($content)) { return $null }
    if ($MaxLines -gt 0) {
        $lines = $content -split "`r?`n"
        if ($lines.Count -gt $MaxLines) {
            $lines = $lines[0..($MaxLines - 1)]
            $content = ($lines -join [Environment]::NewLine) + [Environment]::NewLine + '... (truncated)'
        }
    }
    return $content.TrimEnd()
}

function Read-ControlDocSummary {
    param([string]$RepoRoot, [string]$FileName, [int]$HeadLines = 60)
    $full = Join-Path $RepoRoot $FileName
    if (-not (Test-Path -LiteralPath $full)) { return $null }
    $content = Get-Content -LiteralPath $full -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($content)) { return $null }
    $lines = $content -split "`r?`n"
    if ($lines.Count -gt $HeadLines) {
        $lines = $lines[0..($HeadLines - 1)]
        return ($lines -join [Environment]::NewLine) + [Environment]::NewLine + ('... (truncated; full file at ' + $FileName + ')')
    }
    return ($content.TrimEnd())
}

function Block-OrPlaceholder {
    param([string]$Content, [string]$Placeholder = '(not generated)')
    if ([string]::IsNullOrWhiteSpace($Content)) { return $Placeholder }
    return $Content
}

$goalText = if ([string]::IsNullOrWhiteSpace($Goal))   { '(not provided)' } else { $Goal }
$taskText = if ([string]::IsNullOrWhiteSpace($TaskId)) { '(not provided)' } else { $TaskId }

# Read run-folder summary artifacts only. We deliberately do NOT include raw
# diffs, source contents, or anything that could leak secret material. The
# harness has already filtered git context for secret-like paths upstream.
$gitStatus    = Read-Artifact -Path (Join-Path $RunFolder 'git-status.txt')
$diffStat     = Read-Artifact -Path (Join-Path $RunFolder 'git-diff-stat.txt')
$diffNames    = Read-Artifact -Path (Join-Path $RunFolder 'git-diff-names.txt')
$detectedMd   = Read-Artifact -Path (Join-Path $RunFolder 'detected-tests.md')
$testSummary  = Read-Artifact -Path (Join-Path $RunFolder 'test-summary.json')
$handoffMd    = Read-Artifact -Path (Join-Path $RunFolder 'AI_FINAL_HANDOFF.md')
$goalTxt      = Read-Artifact -Path (Join-Path $RunFolder 'goal.txt')

# Read short heads of project control documents. Codex itself can re-read them
# in the working repo; we embed short summaries so the prompt is self-contained.
$specSummary     = Read-ControlDocSummary -RepoRoot $repoRoot -FileName 'AI_PRODUCT_SPEC.md'
$criteriaSummary = Read-ControlDocSummary -RepoRoot $repoRoot -FileName 'AI_ACCEPTANCE_CRITERIA.md'
$queueSummary    = Read-ControlDocSummary -RepoRoot $repoRoot -FileName 'AI_TASK_QUEUE.md'
$workflowSummary = Read-ControlDocSummary -RepoRoot $repoRoot -FileName 'AI_WORKFLOW.md'
$agentsSummary   = Read-ControlDocSummary -RepoRoot $repoRoot -FileName 'AGENTS.md'

$bt    = [char]96
$fence = '' + $bt + $bt + $bt

$lines = @()
$lines += '# Codex Implementation Prompt (Phase 4)'
$lines += ''
$lines += '## Implementer-Only Directive'
$lines += ''
$lines += '**Act as an implementer only. Make the smallest safe change for the current Goal or TaskId. Stop and report if requirements are unclear.**'
$lines += ''
$lines += 'You are running locally as Codex CLI (`codex exec`) in `--sandbox workspace-write` mode. You may read repository files and propose edits to files inside the working directory. You must obey every safety rule listed below. If a rule conflicts with the requested change, stop and report instead of proceeding.'
$lines += ''
$lines += '## Run Parameters'
$lines += ''
$lines += ('- Goal: ' + $goalText)
$lines += ('- TaskId: ' + $taskText)
$lines += ('- TestLevel: ' + $TestLevel)
$lines += ('- SkipE2E: ' + [bool]$SkipE2E)
$lines += ('- DryRun: ' + [bool]$DryRun)
$lines += ('- RunFolder: ' + $RunFolder)
$lines += ('- RepoRoot: ' + $repoRoot)
$lines += ''
$lines += '## Strict Safety Rules'
$lines += ''
$lines += '- Do NOT run `git commit`, `git push`, `git tag`, or any deploy command.'
$lines += '- Do NOT install dependencies (`npm`, `pnpm`, `yarn`, `pip`, `poetry`, `uv`, etc.).'
$lines += '- Do NOT modify `package.json`, lockfiles, or CI configuration unless the active task explicitly requires it.'
$lines += '- Do NOT read or print secret material. Treat any path matching `.env`, `.env.*`, `*.pem`, `*.key`, `*secret*`, `*token*`, `*credential*`, or `credentials.json` as off-limits.'
$lines += '- Do NOT run destructive shell commands (`rm -rf`, `Remove-Item -Recurse -Force` outside the active run folder, `git reset --hard`, force pushes).'
$lines += '- Do NOT modify files outside the repository root.'
$lines += '- Do NOT modify files outside the allowed list for the current phase as defined in `AGENTS.md` / `CLAUDE.md`. If a task appears to require expansion of scope, stop and report.'
$lines += '- Do NOT perform broad refactors, opportunistic cleanups, or unrelated reformatting. Keep the diff minimal and focused on the active Goal or TaskId.'
$lines += '- Do NOT request `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, `--full-auto`, yolo, or any permissive sandbox mode.'
$lines += '- Do NOT introduce automatic retries, fix loops, or follow-up Codex/Claude calls.'
$lines += '- Surface uncertainty rather than guessing. If acceptance criteria, scope, or expected behavior are ambiguous, stop and emit a clarifying question instead of guessing.'
$lines += ''
$lines += '## Repository Control Documents'
$lines += ''
$lines += 'Codex CLI also reads these files directly from the working repository. The summaries below are heads of each file at the moment this prompt was generated.'
$lines += ''
$lines += '### AI_PRODUCT_SPEC.md (head)'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $specSummary)
$lines += $fence
$lines += ''
$lines += '### AI_ACCEPTANCE_CRITERIA.md (head)'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $criteriaSummary)
$lines += $fence
$lines += ''
$lines += '### AI_TASK_QUEUE.md (head)'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $queueSummary)
$lines += $fence
$lines += ''
$lines += '### AI_WORKFLOW.md (head)'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $workflowSummary)
$lines += $fence
$lines += ''
$lines += '### AGENTS.md (head)'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $agentsSummary)
$lines += $fence
$lines += ''
$lines += '## Run Goal Snapshot'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $goalTxt '(no goal.txt captured)')
$lines += $fence
$lines += ''
$lines += '## Current Git Status (filtered)'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $gitStatus)
$lines += $fence
$lines += ''
$lines += '## Current Diff Stat'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $diffStat)
$lines += $fence
$lines += ''
$lines += '## Files Changed (filtered)'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $diffNames)
$lines += $fence
$lines += ''
$lines += '## Detected Tests (summary)'
$lines += ''
$lines += (Block-OrPlaceholder $detectedMd)
$lines += ''
$lines += '## Most Recent Test Summary (JSON)'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $testSummary '(no test-summary.json yet)')
$lines += $fence
$lines += ''
if (-not [string]::IsNullOrWhiteSpace($handoffMd)) {
    $lines += '## Previous Handoff (if available)'
    $lines += ''
    $lines += $handoffMd
    $lines += ''
}
$lines += '## Out-of-Scope Material'
$lines += ''
$lines += '- This prompt does NOT include raw file diffs, full source contents, or secret material.'
$lines += '- This prompt does NOT include credential paths or environment variable values.'
$lines += '- Codex CLI may read repository files directly when needed; do not assume the prompt is exhaustive.'
$lines += ''
$lines += '## Required Final Response Format'
$lines += ''
$lines += 'After making (or refusing to make) edits, respond with the following structured markdown. Do not add other top-level sections.'
$lines += ''
$lines += $fence + 'markdown'
$lines += '# Codex Implementation Result'
$lines += ''
$lines += '## Summary'
$lines += ''
$lines += '<2-5 sentences describing what was changed (or why nothing was changed).>'
$lines += ''
$lines += '## Files Changed'
$lines += ''
$lines += '- <relative/path/to/file>: <short description of the change>'
$lines += ''
$lines += '## Tests Run Or Not Run'
$lines += ''
$lines += '<Did Codex run any tests? At what level? Results? If not, why not?>'
$lines += ''
$lines += '## Risks'
$lines += ''
$lines += '- <risk 1>'
$lines += '- <risk 2>'
$lines += ''
$lines += '## Follow-up Needed'
$lines += ''
$lines += '- <next step the human reviewer should take>'
$lines += $fence

$outPath = Join-Path $RunFolder 'codex-implementation-prompt.md'
($lines -join [Environment]::NewLine) | Out-File -FilePath $outPath -Encoding utf8

Write-Host "[codex-prompt] Wrote $outPath"
