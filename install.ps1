# Install GitKraken CLI (gk) on Windows via winget.
# Usage (PowerShell):  .\install.ps1

$ErrorActionPreference = 'Stop'
$PackageId = 'GitKraken.cli'

if (Get-Command gk -ErrorAction SilentlyContinue) {
    Write-Host "[gk-install] gk already installed: $(gk version | Select-Object -First 1)"
    exit 0
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install 'App Installer' from Microsoft Store and retry."
}

Write-Host "[gk-install] Installing $PackageId via winget..."
winget install --id $PackageId --exact --source winget `
    --accept-package-agreements --accept-source-agreements

if ($LASTEXITCODE -ne 0) {
    throw "winget exited with code $LASTEXITCODE. Check the ID with: winget search gitkraken"
}

# Refresh PATH for the current session
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')

if (Get-Command gk -ErrorAction SilentlyContinue) {
    Write-Host "[gk-install] Installed: $(gk version | Select-Object -First 1)"
    Write-Host "[gk-install] Next step: gk auth login"
} else {
    Write-Warning "Installed, but 'gk' is not on PATH yet. Open a new terminal."
}
