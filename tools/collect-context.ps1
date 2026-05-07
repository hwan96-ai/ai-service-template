[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RunFolder
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $RunFolder)) {
    throw "collect-context: run folder does not exist: $RunFolder"
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

# git status --short
$statusOut = git status --short 2>&1
$statusPath = Join-Path $RunFolder 'git-status.txt'
$statusFiltered = @()
foreach ($line in @($statusOut)) {
    $text = [string]$line
    if (Test-IsSecretLike $text) {
        $statusFiltered += '[redacted secret-like path]'
    } else {
        $statusFiltered += $text
    }
}
($statusFiltered -join [Environment]::NewLine) | Out-File -FilePath $statusPath -Encoding utf8

# git diff --stat
$diffStatOut = git diff --stat 2>&1
$diffStatPath = Join-Path $RunFolder 'git-diff-stat.txt'
($diffStatOut -join [Environment]::NewLine) | Out-File -FilePath $diffStatPath -Encoding utf8

# git diff --name-only (filter secret-like paths)
$diffNamesOut = git diff --name-only 2>&1
$diffNamesPath = Join-Path $RunFolder 'git-diff-names.txt'
$namesFiltered = @()
foreach ($line in @($diffNamesOut)) {
    $text = [string]$line
    if (Test-IsSecretLike $text) {
        $namesFiltered += '[redacted secret-like path]'
    } else {
        $namesFiltered += $text
    }
}
($namesFiltered -join [Environment]::NewLine) | Out-File -FilePath $diffNamesPath -Encoding utf8

$statusCount = @($statusFiltered | Where-Object { $_ -ne '' }).Count
$nameCount   = @($namesFiltered | Where-Object { $_ -ne '' }).Count

Write-Host "[collect-context] git-status entries: $statusCount"
Write-Host "[collect-context] git-diff names: $nameCount (secret-like paths redacted)"
Write-Host "[collect-context] artifacts written under $RunFolder"
