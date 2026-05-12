[CmdletBinding()]
param(
    [string]$TargetRepo = '.',
    [string]$Version = 'v0.6.5',
    [switch]$Apply,
    [switch]$IncludeLocalGitignoreRules
)

$ErrorActionPreference = 'Stop'

Write-Host '=== install-ai-service-template ==='
Write-Host ("[install] TargetRepo: {0}" -f $TargetRepo)
Write-Host ("[install] Version:    {0}" -f $Version)
Write-Host ("[install] Mode:       {0}" -f $(if ($Apply) { 'APPLY' } else { 'PREVIEW' }))

if ([string]::IsNullOrWhiteSpace($TargetRepo)) {
    Write-Error 'TargetRepo must not be empty.'
    exit 2
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    Write-Error 'Version must not be empty.'
    exit 2
}

if (-not $env:TEMP -or -not (Test-Path -LiteralPath $env:TEMP)) {
    Write-Error 'TEMP directory is unavailable. Cannot create extraction folder.'
    exit 2
}

try {
    $resolvedTarget = (Resolve-Path -LiteralPath $TargetRepo).ProviderPath
} catch {
    Write-Error ("Failed to resolve TargetRepo '{0}': {1}" -f $TargetRepo, $_.Exception.Message)
    exit 2
}

$archiveUrl = "https://github.com/hwan96-ai/ai-service-template/archive/refs/tags/$Version.zip"
$tempRoot = Join-Path $env:TEMP ("ai-service-template-install-{0}" -f ([Guid]::NewGuid().ToString('N')))
$archivePath = Join-Path $tempRoot 'template.zip'
$extractPath = Join-Path $tempRoot 'extracted'

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
} catch {
    Write-Error ("Failed to create temporary extraction folders under TEMP: {0}" -f $_.Exception.Message)
    exit 2
}

Write-Host ("[install] Downloading archive: {0}" -f $archiveUrl)
try {
    Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath -UseBasicParsing
} catch {
    Write-Error ("Failed to download template archive for version '{0}': {1}" -f $Version, $_.Exception.Message)
    exit 2
}

if (-not (Test-Path -LiteralPath $archivePath)) {
    Write-Error ("Download did not create expected archive: {0}" -f $archivePath)
    exit 2
}

Write-Host ("[install] Extracting archive under: {0}" -f $extractPath)
try {
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath -Force
} catch {
    Write-Error ("Failed to extract template archive: {0}" -f $_.Exception.Message)
    exit 2
}

$copyScripts = @(Get-ChildItem -LiteralPath $extractPath -Recurse -File -Filter 'copy-template-to-service.ps1' | Where-Object {
    $_.FullName -match '[\\/]tools[\\/]copy-template-to-service\.ps1$'
})

if ($copyScripts.Count -lt 1) {
    Write-Error ("Could not find tools/copy-template-to-service.ps1 in extracted archive: {0}" -f $extractPath)
    exit 2
}

if ($copyScripts.Count -gt 1) {
    Write-Error ("Found multiple copy-template-to-service.ps1 files in extracted archive. Refusing to guess. Root: {0}" -f $extractPath)
    exit 2
}

$copyScript = $copyScripts[0].FullName
Write-Host ("[install] Copy script: {0}" -f $copyScript)
Write-Host ("[install] Running copy script in {0} mode." -f $(if ($Apply) { 'apply' } else { 'preview' }))

$copyArgs = @('-TargetRepo', $resolvedTarget)
if ($Apply) {
    $copyArgs += '-Apply'
}
if ($IncludeLocalGitignoreRules) {
    $copyArgs += '-IncludeLocalGitignoreRules'
}

& $copyScript @copyArgs
exit $LASTEXITCODE
