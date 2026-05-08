[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RunFolder
)

# Use Continue (not Stop) so harmless native git stderr noise (e.g. LF/CRLF
# warnings emitted by core.autocrlf) cannot abort the script. We invoke git
# through cmd.exe and redirect stderr to NUL at the cmd level so PowerShell
# never wraps native stderr lines into terminating ErrorRecords.
$ErrorActionPreference = 'Continue'

if (-not (Test-Path -LiteralPath $RunFolder)) {
    Write-Error "collect-context: run folder does not exist: $RunFolder"
    exit 2
}

$secretPatterns = @(
    '(^|/)\.env(\.|$)',
    '\.pem$',
    '\.key$',
    'secret',
    'credentials'
)

function Test-IsSecretLike {
    param([string]$Line)
    if ([string]::IsNullOrWhiteSpace($Line)) { return $false }
    foreach ($pat in $secretPatterns) {
        if ($Line -match $pat) { return $true }
    }
    return $false
}

function Invoke-GitStdoutOnly {
    # Run a git invocation through cmd.exe so its stderr is dropped at the
    # cmd-level redirection (2>NUL) and PowerShell only ever sees stdout.
    # Returns an array of stdout lines (possibly empty). $LASTEXITCODE is
    # set to git's exit code. The leading comma forces PowerShell to preserve
    # the wrapper array even when the inner result is empty, so callers do
    # not silently receive $null when git produced no output.
    param([Parameter(Mandatory)][string]$GitArgs)
    $cmdLine = "git $GitArgs 2>NUL"
    $output = cmd.exe /c $cmdLine
    if ($null -eq $output) { return ,@() }
    if ($output -is [string]) { return ,@($output) }
    return ,@($output)
}

function Write-FilteredLines {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Lines,
        [switch]$FilterSecrets
    )
    # Treat $null and empty input identically — empty git output is normal,
    # not an error. The output file is always written so downstream tooling
    # (validate-template-install, write-final-handoff, fix-loop) can rely
    # on its presence.
    if ($null -eq $Lines) { $Lines = @() }
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in $Lines) {
        $text = [string]$line
        if ($FilterSecrets -and (Test-IsSecretLike $text)) {
            [void]$out.Add('[redacted secret-like path]')
        } else {
            [void]$out.Add($text)
        }
    }
    if ($out.Count -eq 0) {
        Set-Content -LiteralPath $Path -Value '' -Encoding utf8
    } else {
        ($out -join [Environment]::NewLine) | Out-File -FilePath $Path -Encoding utf8
    }
}

# git status --short (stdout only; secret-like paths redacted)
# Wrap each Invoke-GitStdoutOnly call in @(...) as belt-and-suspenders against
# PowerShell array unwrap on assignment.
$statusPath = Join-Path $RunFolder 'git-status.txt'
$statusOut  = @(Invoke-GitStdoutOnly -GitArgs 'status --short')
$statusExit = $LASTEXITCODE
Write-FilteredLines -Path $statusPath -Lines $statusOut -FilterSecrets

# git diff --stat (stdout only; no path filtering needed — stat lines include line counts, not contents)
$diffStatPath = Join-Path $RunFolder 'git-diff-stat.txt'
$diffStatOut  = @(Invoke-GitStdoutOnly -GitArgs 'diff --stat')
$diffStatExit = $LASTEXITCODE
Write-FilteredLines -Path $diffStatPath -Lines $diffStatOut

# git diff --name-only (stdout only; secret-like paths redacted)
$diffNamesPath = Join-Path $RunFolder 'git-diff-names.txt'
$diffNamesOut  = @(Invoke-GitStdoutOnly -GitArgs 'diff --name-only')
$diffNamesExit = $LASTEXITCODE
Write-FilteredLines -Path $diffNamesPath -Lines $diffNamesOut -FilterSecrets

$statusCount = @($statusOut    | Where-Object { -not [string]::IsNullOrEmpty([string]$_) }).Count
$nameCount   = @($diffNamesOut | Where-Object { -not [string]::IsNullOrEmpty([string]$_) }).Count

Write-Host ("[collect-context] git-status entries: {0} (exit={1})" -f $statusCount, $statusExit)
Write-Host ("[collect-context] git-diff names: {0} (exit={1}, secret-like paths redacted)" -f $nameCount, $diffNamesExit)
Write-Host ("[collect-context] git-diff stat exit: {0}" -f $diffStatExit)
Write-Host "[collect-context] artifacts written under $RunFolder"
