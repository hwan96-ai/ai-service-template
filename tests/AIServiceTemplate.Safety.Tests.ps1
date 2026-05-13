# Pester-style safety self-tests for the local AI harness.
# These tests do not install dependencies and do not invoke Codex CLI or Claude Code CLI.

Describe 'AI Service Template safety guardrails' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'AIServiceTemplate.Safety.TestHelpers.ps1')
        Initialize-SafetyTestContext
        New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null
    }

    AfterAll {
        $candidate = Resolve-Path -LiteralPath $script:TempRoot -ErrorAction SilentlyContinue
        if ($candidate) {
            $candidatePath = [System.IO.Path]::GetFullPath($candidate.ProviderPath)
            $tempPath = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
            $leaf = Split-Path -Leaf $candidatePath

            if ($candidatePath.StartsWith($tempPath, [System.StringComparison]::OrdinalIgnoreCase) -and
                $leaf.StartsWith('ai-service-template-safety-tests-', [System.StringComparison]::OrdinalIgnoreCase)) {
                Remove-Item -LiteralPath $candidatePath -Recurse -Force
            }
        }
    }

    It 'refuses AutoCommit before creating run output' {
        $work = New-SafetyTempDirectory -Name 'autocommit'

        $result = Invoke-ChildPowerShellScript `
            -ScriptPath $script:AutopilotPath `
            -WorkingDirectory $work `
            -Arguments @('-AutoCommit', '-Goal', 'self-test autocommit refusal')

        Assert-NotEqual $result.ExitCode 0
        Assert-Match $result.Output 'AutoCommit is not permitted'
        Assert-False (Test-Path -LiteralPath (Join-Path $work 'ai-runs'))
    }

    It 'refuses MaxIterations above the safety cap before creating run output' {
        $work = New-SafetyTempDirectory -Name 'maxiterations'

        $result = Invoke-ChildPowerShellScript `
            -ScriptPath $script:AutopilotPath `
            -WorkingDirectory $work `
            -Arguments @('-MaxIterations', '4', '-Goal', 'self-test max iteration refusal')

        $failureContext = @(
            'MaxIterations safety-cap refusal did not meet expectations.',
            "ExitCode: $($result.ExitCode)",
            'Output:',
            $result.Output
        ) -join [Environment]::NewLine

        Assert-NotEqual $result.ExitCode 0
        Assert-Match $result.Output 'MaxIterations must be between\s+1\s+and\s+3' $failureContext
        Assert-False (Test-Path -LiteralPath (Join-Path $work 'ai-runs'))
    }

    It 'refuses non-workspace-write CodexSandbox values before creating run output' {
        foreach ($sandbox in @('danger-full-access', 'read-only', 'bypass', 'yolo', 'full-auto', 'Workspace-write')) {
            $work = New-SafetyTempDirectory -Name 'codex-sandbox'

            $result = Invoke-ChildPowerShellScript `
                -ScriptPath $script:AutopilotPath `
                -WorkingDirectory $work `
                -Arguments @('-CodexSandbox', $sandbox, '-Goal', 'self-test codex sandbox refusal')

            $failureContext = @(
                "CodexSandbox refusal did not meet expectations for value <$sandbox>.",
                "ExitCode: $($result.ExitCode)",
                'Output:',
                $result.Output
            ) -join [Environment]::NewLine

            Assert-NotEqual $result.ExitCode 0
            Assert-Match $result.Output 'CodexSandbox is locked to\s+workspace-?\s*write' $failureContext
            Assert-Match ($result.Output -replace '\s+', '') ([regex]::Escape(($sandbox -replace '\s+', ''))) $failureContext
            Assert-False (Test-Path -LiteralPath (Join-Path $work 'ai-runs'))
        }
    }

    It 'keeps DryRun from invoking Codex or Claude even when run flags are present' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $repo = New-TemplateRuntimeRepo
        $autopilot = Join-Path $repo 'tools\ai-autopilot.ps1'
        Assert-True (Test-Path -LiteralPath $autopilot) "Expected copied autopilot script to exist at <$autopilot>."

        $result = Invoke-ChildPowerShellScript `
            -ScriptPath $autopilot `
            -WorkingDirectory $repo `
            -Arguments @(
                '-DryRun',
                '-Implementer', 'codex',
                '-RunImplementer',
                '-Reviewer', 'claude',
                '-RunReviewer',
                '-Goal', 'self-test dry run suppression'
            )

        $dryRunExpectedOutput = @(
            'DryRun is ON',
            'DryRun suppressed -RunImplementer',
            'DryRun suppressed -RunReviewer'
        )
        $dryRunFailureContext = @(
            'DryRun child PowerShell process did not meet expectations.',
            "Repo: $repo",
            "Autopilot: $autopilot",
            "ExitCode: $($result.ExitCode)",
            ("Expected key strings: {0}" -f ($dryRunExpectedOutput -join ' | ')),
            'Output:',
            $result.Output
        ) -join [Environment]::NewLine

        Assert-Equal $result.ExitCode 0 $dryRunFailureContext
        foreach ($expectedOutput in $dryRunExpectedOutput) {
            Assert-Match $result.Output $expectedOutput ("Expected DryRun output to contain <$expectedOutput>.`n$dryRunFailureContext")
        }

        $runFolder = Get-LatestRunFolder -RepoPath $repo
        Assert-NotNullOrEmpty $runFolder ("Expected DryRun to create an ai-runs child folder.`n$dryRunFailureContext")

        $codexOutputPath = Join-Path $runFolder.FullName 'codex-output.md'
        $claudeOutputPath = Join-Path $runFolder.FullName 'claude-review.md'
        $handoffPath = Join-Path $runFolder.FullName 'AI_FINAL_HANDOFF.md'
        Assert-True (Test-Path -LiteralPath $codexOutputPath) ("Expected DryRun Codex placeholder artifact at <$codexOutputPath>.`n$dryRunFailureContext")
        Assert-True (Test-Path -LiteralPath $claudeOutputPath) ("Expected DryRun Claude placeholder artifact at <$claudeOutputPath>.`n$dryRunFailureContext")
        Assert-True (Test-Path -LiteralPath $handoffPath) ("Expected DryRun final handoff artifact at <$handoffPath>.`n$dryRunFailureContext")

        $codexOutput = Get-Content -LiteralPath $codexOutputPath -Raw
        $claudeOutput = Get-Content -LiteralPath $claudeOutputPath -Raw
        $handoff = Get-Content -LiteralPath $handoffPath -Raw

        Assert-Match $codexOutput 'not executed - DryRun' ("Expected Codex placeholder to prove DryRun suppression.`nPath: $codexOutputPath`nContent:`n$codexOutput")
        Assert-Match $codexOutput 'refused to invoke Codex CLI' ("Expected Codex placeholder to prove Codex CLI was not invoked.`nPath: $codexOutputPath`nContent:`n$codexOutput")
        Assert-Match $claudeOutput 'not executed - DryRun' ("Expected Claude placeholder to prove DryRun suppression.`nPath: $claudeOutputPath`nContent:`n$claudeOutput")
        Assert-Match $claudeOutput 'refused to invoke Claude CLI' ("Expected Claude placeholder to prove Claude CLI was not invoked.`nPath: $claudeOutputPath`nContent:`n$claudeOutput")
        Assert-Match $handoff 'Human review' ("Expected final handoff to preserve human-review gate.`nPath: $handoffPath`nContent:`n$handoff")
    }

    It 'redacts secret-like paths from git diff stat artifacts' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $repo = New-SafetyTempDirectory -Name 'redaction-repo'
        $runFolder = Join-Path $repo 'run-output'
        New-Item -ItemType Directory -Path $runFolder -Force | Out-Null

        $secretPaths = @(
            '.env.local',
            'keys/service.pem',
            'config/api.key',
            'config/service-secret.txt',
            'config/token-cache.txt',
            'config/credentials.json',
            'config/service-credential.txt'
        )

        Push-Location -LiteralPath $repo
        try {
            & git init 2>&1 | Out-Null
            & git config user.name 'Safety Test' 2>&1 | Out-Null
            & git config user.email 'safety@example.invalid' 2>&1 | Out-Null

            foreach ($relative in $secretPaths) {
                $path = Join-Path $repo $relative
                $parent = Split-Path -Parent $path
                if (-not [string]::IsNullOrWhiteSpace($parent)) {
                    New-Item -ItemType Directory -Path $parent -Force | Out-Null
                }
                Set-Content -LiteralPath $path -Value 'placeholder value' -Encoding utf8
            }

            & git add -f . 2>&1 | Out-Null
            & git commit -m 'baseline' 2>&1 | Out-Null

            foreach ($relative in $secretPaths) {
                Add-Content -LiteralPath (Join-Path $repo $relative) -Value 'changed value'
            }

            & $script:CollectContextPath -RunFolder $runFolder | Out-Null
        } finally {
            Pop-Location
        }

        $diffStat = Get-Content -LiteralPath (Join-Path $runFolder 'git-diff-stat.txt') -Raw
        $diffNames = Get-Content -LiteralPath (Join-Path $runFolder 'git-diff-names.txt') -Raw
        $status = Get-Content -LiteralPath (Join-Path $runFolder 'git-status.txt') -Raw

        foreach ($artifactText in @($diffStat, $diffNames, $status)) {
            Assert-Match $artifactText '\[redacted secret-like path\]'
            foreach ($fragment in @('.env.local', 'service.pem', 'api.key', 'service-secret.txt', 'token-cache.txt', 'credentials.json', 'service-credential.txt')) {
                Assert-NotMatch $artifactText ([regex]::Escape($fragment))
            }
        }
    }

    It 'keeps the copy script preview-only by default' {
        $target = New-SafetyTempDirectory -Name 'copy-target'
        New-Item -ItemType Directory -Path (Join-Path $target '.git') -Force | Out-Null

        $result = Invoke-ChildPowerShellScript `
            -ScriptPath $script:CopyScriptPath `
            -WorkingDirectory $script:RepoRoot `
            -Arguments @('-TargetRepo', $target)

        Assert-Equal $result.ExitCode 0
        Assert-Match $result.Output 'PREVIEW'
        Assert-Match $result.Output 'no files were written'

        Assert-False (Test-Path -LiteralPath (Join-Path $target 'AI_PRODUCT_SPEC.md'))
        Assert-False (Test-Path -LiteralPath (Join-Path $target 'tools'))
        Assert-False (Test-Path -LiteralPath (Join-Path $target 'ai-runs'))
    }

    It 'preserves an existing target README unless explicitly opted in' {
        $target = New-SafetyTempDirectory -Name 'copy-readme-target'
        New-Item -ItemType Directory -Path (Join-Path $target '.git') -Force | Out-Null
        $readmePath = Join-Path $target 'README.md'
        $originalReadme = 'service-specific readme'
        Set-Content -LiteralPath $readmePath -Value $originalReadme -Encoding utf8

        $previewResult = Invoke-ChildPowerShellScript `
            -ScriptPath $script:CopyScriptPath `
            -WorkingDirectory $script:RepoRoot `
            -Arguments @('-TargetRepo', $target)

        Assert-Equal $previewResult.ExitCode 0
        Assert-Match $previewResult.Output '\[skip-existing-readme\] README\.md'
        Assert-NotMatch $previewResult.Output '\[overwrite\] README\.md'
        Assert-Equal ((Get-Content -LiteralPath $readmePath -Raw).Trim()) $originalReadme

        $applyResult = Invoke-ChildPowerShellScript `
            -ScriptPath $script:CopyScriptPath `
            -WorkingDirectory $script:RepoRoot `
            -Arguments @('-TargetRepo', $target, '-Apply')

        Assert-Equal $applyResult.ExitCode 0
        Assert-Match $applyResult.Output 'preserved \(readme, no overwrite\): README\.md'
        Assert-Equal ((Get-Content -LiteralPath $readmePath -Raw).Trim()) $originalReadme

        $overwritePreviewResult = Invoke-ChildPowerShellScript `
            -ScriptPath $script:CopyScriptPath `
            -WorkingDirectory $script:RepoRoot `
            -Arguments @('-TargetRepo', $target, '-OverwriteReadme')

        Assert-Equal $overwritePreviewResult.ExitCode 0
        Assert-Match $overwritePreviewResult.Output '\[overwrite\] README\.md'
    }

    It 'includes the AI agent bootstrap document in copy previews' {
        $target = New-SafetyTempDirectory -Name 'copy-bootstrap-target'
        New-Item -ItemType Directory -Path (Join-Path $target '.git') -Force | Out-Null

        $manifest = Get-Content -LiteralPath $script:ManifestPath -Raw | ConvertFrom-Json
        Assert-True ($manifest.requiredFiles -contains 'AI_AGENT_BOOTSTRAP.md')
        Assert-True ($manifest.controlDocuments -contains 'AI_AGENT_BOOTSTRAP.md')

        $previewResult = Invoke-ChildPowerShellScript `
            -ScriptPath $script:CopyScriptPath `
            -WorkingDirectory $script:RepoRoot `
            -Arguments @('-TargetRepo', $target)

        Assert-Equal $previewResult.ExitCode 0
        Assert-Match $previewResult.Output '\[create\] AI_AGENT_BOOTSTRAP\.md'
        Assert-False (Test-Path -LiteralPath (Join-Path $target 'AI_AGENT_BOOTSTRAP.md'))
    }

    It 'preserves existing agent and control docs unless explicitly opted in' {
        $target = New-SafetyTempDirectory -Name 'copy-agent-doc-target'
        New-Item -ItemType Directory -Path (Join-Path $target '.git') -Force | Out-Null

        $existingDocs = @(
            'AGENTS.md',
            'CLAUDE.md',
            'AI_AGENT_BOOTSTRAP.md'
        )

        foreach ($doc in $existingDocs) {
            Set-Content -LiteralPath (Join-Path $target $doc) -Value ("target-owned {0}" -f $doc) -Encoding utf8
        }

        $previewResult = Invoke-ChildPowerShellScript `
            -ScriptPath $script:CopyScriptPath `
            -WorkingDirectory $script:RepoRoot `
            -Arguments @('-TargetRepo', $target)

        Assert-Equal $previewResult.ExitCode 0
        foreach ($doc in $existingDocs) {
            Assert-Match $previewResult.Output ('\[skip-existing-control-doc\] {0}' -f [regex]::Escape($doc))
            Assert-NotMatch $previewResult.Output ('\[overwrite\] {0}' -f [regex]::Escape($doc))
        }

        $applyResult = Invoke-ChildPowerShellScript `
            -ScriptPath $script:CopyScriptPath `
            -WorkingDirectory $script:RepoRoot `
            -Arguments @('-TargetRepo', $target, '-Apply')

        Assert-Equal $applyResult.ExitCode 0
        foreach ($doc in $existingDocs) {
            Assert-Match $applyResult.Output ("preserved \(control doc, no overwrite\): {0}" -f [regex]::Escape($doc))
            Assert-Equal ((Get-Content -LiteralPath (Join-Path $target $doc) -Raw).Trim()) ("target-owned {0}" -f $doc)
        }
    }

    It 'keeps the GitHub installer free of direct execution and release mutation patterns' {
        $installerPath = Join-Path $script:RepoRoot 'tools\install-ai-service-template.ps1'
        $installerText = Get-Content -LiteralPath $installerPath -Raw

        Assert-NotMatch $installerText 'Invoke-Expression'
        Assert-NotMatch $installerText 'iex\b'
        Assert-NotMatch $installerText 'git\s+commit'
        Assert-NotMatch $installerText 'git\s+push'
        Assert-NotMatch $installerText 'git\s+tag'
        Assert-NotMatch $installerText 'gh\s+release'
        Assert-NotMatch $installerText '\bdeploy\b'
    }

    It 'forwards copy-script arguments via a named-parameter hashtable splat' {
        $installerPath = Join-Path $script:RepoRoot 'tools\install-ai-service-template.ps1'
        $installerText = Get-Content -LiteralPath $installerPath -Raw

        # The installer must build a hashtable of named copy-script
        # parameters and splat it. The previous array-based forwarding form
        # (e.g. @('-TargetRepo', $resolvedTarget)) was fragile and surfaced
        # as "A positional parameter cannot be found that accepts argument
        # '<path>'." against the published archive.
        Assert-Match $installerText '\$copyParams\s*=\s*@\{'
        Assert-Match $installerText 'TargetRepo\s*=\s*\$resolvedTarget'
        Assert-Match $installerText '\$copyParams\[''Apply''\]\s*=\s*\$true'
        Assert-Match $installerText '\$copyParams\[''IncludeLocalGitignoreRules''\]\s*=\s*\$true'
        Assert-Match $installerText '&\s+\$copyScript\s+@copyParams'

        # The fragile array-splat shape that triggered the v0.6.6 regression
        # must not return. Detect either the array literal containing
        # '-TargetRepo' or the @copyArgs splat at the call site.
        Assert-NotMatch $installerText '@\(\s*''-TargetRepo'''
        Assert-NotMatch $installerText '&\s+\$copyScript\s+@copyArgs'
    }

    It 'parses the installer cleanly and exposes the expected forwarding parameters' {
        $installerPath = Join-Path $script:RepoRoot 'tools\install-ai-service-template.ps1'
        $installerText = Get-Content -LiteralPath $installerPath -Raw

        $parseErrors = $null
        [System.Management.Automation.PSParser]::Tokenize($installerText, [ref]$parseErrors) | Out-Null
        $parseErrorText = (@($parseErrors) | ForEach-Object { $_.Message }) -join [Environment]::NewLine
        Assert-Equal @($parseErrors).Count 0 "Expected installer to parse cleanly. Parse errors:`n$parseErrorText"

        Assert-Match $installerText '\[string\]\$TargetRepo\b'
        Assert-Match $installerText '\[switch\]\$Apply\b'
        Assert-Match $installerText '\[switch\]\$IncludeLocalGitignoreRules\b'
    }

    It 'keeps Windows PowerShell executed harness scripts ASCII-safe and parseable' {
        $toolScripts = @(
            'tools\detect-tests.ps1',
            'tools\write-final-handoff.ps1'
        )

        foreach ($relativePath in $toolScripts) {
            $scriptPath = Join-Path $script:RepoRoot $relativePath
            $scriptText = Get-Content -LiteralPath $scriptPath -Raw
            Assert-NotMatch $scriptText '[^\x00-\x7F]' "Expected <$relativePath> to contain ASCII-only executable script text for Windows PowerShell 5.1 compatibility."

            $legacyDecodedText = [System.Text.Encoding]::Default.GetString([System.IO.File]::ReadAllBytes($scriptPath))
            $tokens = $null
            $parseErrors = $null
            [System.Management.Automation.PSParser]::Tokenize($legacyDecodedText, [ref]$parseErrors) | Out-Null

            $parseErrorText = (@($parseErrors) | ForEach-Object { $_.Message }) -join [Environment]::NewLine
            Assert-Equal @($parseErrors).Count 0 "Expected <$relativePath> to parse cleanly after Windows PowerShell default-encoding decode. Parse errors:`n$parseErrorText"
        }
    }

    It 'documents forbidden safety terms in the manifest and harness' {
        $manifest = Get-Content -LiteralPath $script:ManifestPath -Raw | ConvertFrom-Json
        $combinedText = @(
            Get-Content -LiteralPath $script:ManifestPath -Raw
            Get-Content -LiteralPath $script:AutopilotPath -Raw
        ) -join [Environment]::NewLine

        foreach ($term in @(
            'git commit',
            'git push',
            'deploy',
            'install',
            'danger-full-access',
            'bypass',
            'yolo',
            'full-auto'
        )) {
            Assert-Match $combinedText ([regex]::Escape($term))
        }

        Assert-False $manifest.autoCommit
        Assert-False $manifest.autoPush
        Assert-False $manifest.autoDeploy
        Assert-True $manifest.humanApprovalRequired
    }

    It 'documents selected local checks as trusted-repository opt-in checks with script-internal limitations' {
        $combinedDocs = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot 'README.md') -Raw
            Get-Content -LiteralPath (Join-Path $script:RepoRoot 'TEMPLATE_USAGE.md') -Raw
            Get-Content -LiteralPath (Join-Path $script:RepoRoot 'AI_WORKFLOW.md') -Raw
            Get-Content -LiteralPath (Join-Path $script:RepoRoot 'AI_ACCEPTANCE_CRITERIA.md') -Raw
            Get-Content -LiteralPath (Join-Path $script:RepoRoot 'SECURITY.md') -Raw
        ) -join [Environment]::NewLine

        Assert-Match $combinedDocs 'selected opt-in local checks from trusted repositories'
        Assert-Match $combinedDocs 'deny-lists wrapper command text'
        Assert-Match $combinedDocs 'cannot guarantee'
        Assert-Match $combinedDocs 'side effects'
        Assert-NotMatch $combinedDocs 'safe tests'
    }

    It 'keeps generated run artifacts and Claude local state out of source control intent' {
        $gitignoreText = Get-Content -LiteralPath $script:GitignorePath -Raw
        $manifest = Get-Content -LiteralPath $script:ManifestPath -Raw | ConvertFrom-Json
        $copyScriptText = Get-Content -LiteralPath $script:CopyScriptPath -Raw

        Assert-Match $gitignoreText 'ai-runs/\*'
        Assert-Match $gitignoreText '!ai-runs/\.gitkeep'
        Assert-Match $gitignoreText '\.claude/'

        Assert-True ($manifest.localArtifactPatterns -contains 'ai-runs/*')
        Assert-True ($manifest.localArtifactPatterns -contains '.claude/')
        Assert-True ($manifest.neverCopy -contains '.claude')
        Assert-True ($manifest.neverCopy -contains 'ai-runs/[0-9]*')

        Assert-Match $copyScriptText 'ai-runs/\.gitkeep'
        Assert-Match $copyScriptText '\.claude'
    }
}

Describe 'Public release safety regressions' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'AIServiceTemplate.Safety.TestHelpers.ps1')
        Initialize-SafetyTestContext
    }

    It 'omits raw local check output from Claude review prompts' {
        $scriptPath = Join-Path $script:RepoRoot 'tools\write-claude-review-prompt.ps1'
        $tempRun = Join-Path ([System.IO.Path]::GetTempPath()) ('ai-service-template-claude-review-' + [Guid]::NewGuid().ToString('N'))

        New-Item -ItemType Directory -Path $tempRun -Force | Out-Null

        try {
            Set-Content -Path (Join-Path $tempRun 'test-output.txt') -Encoding UTF8 -Value @(
                'SECRET_TOKEN_SHOULD_NOT_APPEAR',
                'fake-password',
                'connection string'
            )
            Set-Content -Path (Join-Path $tempRun 'test-summary.json') -Encoding UTF8 -Value '{"status":"failed","failed":1,"passed":0}'
            Set-Content -Path (Join-Path $tempRun 'git-status.txt') -Encoding UTF8 -Value ' M src/example.ps1'
            Set-Content -Path (Join-Path $tempRun 'git-diff-stat.txt') -Encoding UTF8 -Value ' src/example.ps1 | 2 +-'
            Set-Content -Path (Join-Path $tempRun 'git-diff-names.txt') -Encoding UTF8 -Value 'src/example.ps1'

            & $scriptPath -RunFolder $tempRun

            $promptPath = Join-Path $tempRun 'claude-review-prompt.md'
            Assert-True (Test-Path -LiteralPath $promptPath)

            $prompt = Get-Content -LiteralPath $promptPath -Raw
            Assert-NotMatch $prompt 'SECRET_TOKEN_SHOULD_NOT_APPEAR'
            Assert-NotMatch $prompt 'fake-password'
            Assert-NotMatch $prompt 'connection string'
            Assert-Match $prompt 'raw test output intentionally omitted/redacted for safety'
            Assert-Match $prompt 'test-output\.txt is available only for local human review'
        } finally {
            if (Test-Path -LiteralPath $tempRun) {
                Remove-Item -LiteralPath $tempRun -Recurse -Force
            }
        }
    }

    It 'uses trusted local-check wording in release-facing artifacts' {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'TEMPLATE_MANIFEST.json') -Raw
        Assert-DoesNotThrow { $manifest | ConvertFrom-Json }
        Assert-NotMatch $manifest 'Run safe unit-level tests'
        Assert-Match $manifest 'Run selected unit-level local checks from a trusted repository'
        Assert-True ((($manifest | ConvertFrom-Json).requiredFiles) -contains 'SECURITY.md')

        $sampleHandoff = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'examples\sample-AI_FINAL_HANDOFF.md') -Raw
        Assert-NotMatch $sampleHandoff 'Confirm detected test commands are safe and expected'
        Assert-Match $sampleHandoff 'trusted, expected, and acceptable to run locally'

        $detectTests = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'tools\detect-tests.ps1') -Raw
        Assert-NotMatch $detectTests 'safe-by-default'
        Assert-Match $detectTests 'default-selected'

        $fixPrompt = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'tools\write-codex-fix-prompt.ps1') -Raw
        Assert-Match $fixPrompt 'token'
        Assert-Match $fixPrompt 'credential'
        Assert-Match $fixPrompt 'credentials\.json'
    }

    It 'keeps review and implementation prompt safety wording aligned' {
        $claudePromptScript = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'tools\write-claude-review-prompt.ps1') -Raw
        $codexPromptScript = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'tools\write-codex-implementation-prompt.ps1') -Raw

        Assert-Match $claudePromptScript '## Test Output Notice'
        Assert-NotMatch $claudePromptScript '## Test Output \(head\)'

        foreach ($pattern in @(
            '\.env',
            '\.env\.\*',
            '\*\.pem',
            '\*\.key',
            '\*secret\*',
            '\*token\*',
            '\*credential\*',
            'credentials\.json'
        )) {
            Assert-Match $codexPromptScript $pattern
        }
    }
}
