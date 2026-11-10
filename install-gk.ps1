# Install GitKraken CLI (gk) on Windows via winget.
# Usage: powershell -ExecutionPolicy Bypass -File .\install-gk.ps1 [-Version 3.1.0]
[CmdletBinding()]
param(
    [string]$Version
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget not found. Install "App Installer" from the Microsoft Store.'
}

$wingetArgs = @(
    'install', '--id', 'GitKraken.cli', '--exact',
    '--source', 'winget',
    '--accept-source-agreements', '--accept-package-agreements'
)
if ($Version) { $wingetArgs += @('--version', $Version) }

& winget @wingetArgs
# -1978335189 (0x8A15002B): already installed / no applicable upgrade
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
    throw "winget failed with exit code $LASTEXITCODE"
}

# Refresh PATH for the current session
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')

if (Get-Command gk -ErrorAction SilentlyContinue) {
    gk version
} else {
    Write-Warning 'gk installed, but not on PATH yet; open a new terminal.'
}
