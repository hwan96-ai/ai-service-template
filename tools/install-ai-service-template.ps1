[CmdletBinding()]
param(
    [string]$TargetRepo = '.',
    [string]$Version = 'v0.6.8',
    [switch]$Apply,
    [switch]$IncludeLocalGitignoreRules
)

$ErrorActionPreference = 'Stop'

function Write-InstallLog {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host ("[install] {0}" -f $Message)
}

function Stop-InstallWithError {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [int]$ExitCode = 2
    )
    Write-Error $Message
    exit $ExitCode
}

function Assert-NonEmptyParameter {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if ([string]::IsNullOrWhiteSpace($Value)) {
        Stop-InstallWithError -Message ("{0} must not be empty." -f $Name)
    }
}

function Resolve-TargetRepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        return (Resolve-Path -LiteralPath $Path).ProviderPath
    } catch {
        Stop-InstallWithError -Message ("Failed to resolve TargetRepo '{0}': {1}" -f $Path, $_.Exception.Message)
    }
}

function New-InstallWorkspace {
    if (-not $env:TEMP -or -not (Test-Path -LiteralPath $env:TEMP)) {
        Stop-InstallWithError -Message 'TEMP directory is unavailable. Cannot create extraction folder.'
    }

    $root = Join-Path $env:TEMP ("ai-service-template-install-{0}" -f ([Guid]::NewGuid().ToString('N')))
    $extract = Join-Path $root 'extracted'

    try {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        New-Item -ItemType Directory -Path $extract -Force | Out-Null
    } catch {
        Stop-InstallWithError -Message ("Failed to create temporary extraction folders under TEMP: {0}" -f $_.Exception.Message)
    }

    return [pscustomobject]@{
        Root        = $root
        ArchivePath = Join-Path $root 'template.zip'
        ExtractPath = $extract
    }
}

function Get-TemplateArchive {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$VersionTag
    )

    Write-InstallLog ("Downloading archive: {0}" -f $Url)
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    } catch {
        Stop-InstallWithError -Message ("Failed to download template archive for version '{0}': {1}" -f $VersionTag, $_.Exception.Message)
    }

    if (-not (Test-Path -LiteralPath $Destination)) {
        Stop-InstallWithError -Message ("Download did not create expected archive: {0}" -f $Destination)
    }
}

function Expand-TemplateArchive {
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$ExtractPath
    )

    Write-InstallLog ("Extracting archive under: {0}" -f $ExtractPath)
    try {
        Expand-Archive -LiteralPath $ArchivePath -DestinationPath $ExtractPath -Force
    } catch {
        Stop-InstallWithError -Message ("Failed to extract template archive: {0}" -f $_.Exception.Message)
    }
}

function Find-CopyScript {
    param([Parameter(Mandatory = $true)][string]$ExtractPath)

    $candidates = @(Get-ChildItem -LiteralPath $ExtractPath -Recurse -File -Filter 'copy-template-to-service.ps1' | Where-Object {
        $_.FullName -match '[\\/]tools[\\/]copy-template-to-service\.ps1$'
    })

    if ($candidates.Count -lt 1) {
        Stop-InstallWithError -Message ("Could not find tools/copy-template-to-service.ps1 in extracted archive: {0}" -f $ExtractPath)
    }
    if ($candidates.Count -gt 1) {
        Stop-InstallWithError -Message ("Found multiple copy-template-to-service.ps1 files in extracted archive. Refusing to guess. Root: {0}" -f $ExtractPath)
    }

    return $candidates[0].FullName
}

Write-Host '=== install-ai-service-template ==='
Write-InstallLog ("TargetRepo: {0}" -f $TargetRepo)
Write-InstallLog ("Version:    {0}" -f $Version)
Write-InstallLog ("Mode:       {0}" -f $(if ($Apply) { 'APPLY' } else { 'PREVIEW' }))

Assert-NonEmptyParameter -Value $TargetRepo -Name 'TargetRepo'
Assert-NonEmptyParameter -Value $Version -Name 'Version'

$resolvedTarget = Resolve-TargetRepoPath -Path $TargetRepo

$workspace  = New-InstallWorkspace
$archiveUrl = "https://github.com/hwan96-ai/ai-service-template/archive/refs/tags/$Version.zip"

Get-TemplateArchive -Url $archiveUrl -Destination $workspace.ArchivePath -VersionTag $Version
Expand-TemplateArchive -ArchivePath $workspace.ArchivePath -ExtractPath $workspace.ExtractPath

$copyScript = Find-CopyScript -ExtractPath $workspace.ExtractPath
Write-InstallLog ("Copy script: {0}" -f $copyScript)
Write-InstallLog ("Running copy script in {0} mode." -f $(if ($Apply) { 'apply' } else { 'preview' }))

# Use a hashtable splat to forward named parameters to the copy script.
# An earlier array-of-strings forwarding form was fragile across PowerShell
# versions and could surface as:
#   "A positional parameter cannot be found that accepts argument '<path>'."
# Hashtable splat binds by parameter name and is robust against that class
# of regression.
$copyParams = @{
    TargetRepo = $resolvedTarget
}
if ($Apply) {
    $copyParams['Apply'] = $true
}
if ($IncludeLocalGitignoreRules) {
    $copyParams['IncludeLocalGitignoreRules'] = $true
}

& $copyScript @copyParams
exit $LASTEXITCODE
