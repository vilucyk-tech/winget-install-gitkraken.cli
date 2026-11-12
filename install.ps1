#Requires -Version 5.1
<#
.SYNOPSIS
    Installs (or upgrades) the GitKraken CLI (gk) via winget.
.PARAMETER Upgrade
    Upgrade the package if it is already installed.
#>
[CmdletBinding()]
param(
    [switch]$Upgrade
)

$ErrorActionPreference = 'Stop'
$PackageId = 'GitKraken.cli'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error 'winget not found. Install "App Installer" from the Microsoft Store and retry.'
    exit 1
}

$common = @('--id', $PackageId, '--exact', '--source', 'winget',
            '--accept-source-agreements', '--accept-package-agreements')

winget list --id $PackageId --exact --source winget --accept-source-agreements | Out-Null
$installed = ($LASTEXITCODE -eq 0)

if ($installed -and -not $Upgrade) {
    Write-Host "$PackageId is already installed. Re-run with -Upgrade to update it."
} elseif ($installed) {
    winget upgrade @common
    # -1978335189 = APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE (already up to date)
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
        Write-Error "winget upgrade failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
} else {
    winget install @common
    if ($LASTEXITCODE -ne 0) {
        Write-Error "winget install failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}

# Refresh PATH in the current session so gk is usable without reopening the terminal
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')

if (Get-Command gk -ErrorAction SilentlyContinue) {
    gk version
    Write-Host 'Done. Next step: gk auth login'
} else {
    Write-Warning 'Installed, but gk is not on PATH in this session yet. Open a new terminal and run: gk version'
}
