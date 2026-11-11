#Requires -RunAsAdministrator
#Requires -Modules Hyper-V
<#
.SYNOPSIS
    Creates a MikroTik RouterOS CHR (Cloud Hosted Router) virtual machine in Hyper-V.

.DESCRIPTION
    1. Resolves the RouterOS version (latest stable v7 unless -Version is given).
    2. Downloads chr-<version>.vhdx.zip from download.mikrotik.com and unpacks it.
    3. Creates a private switch for the LAN side (if missing).
    4. Creates a Generation 1 VM: ether1 = WAN (default: "Default Switch", NAT + DHCP),
       ether2 = LAN (private switch).
    5. Starts the VM.

.EXAMPLE
    .\New-ChrVm.ps1
.EXAMPLE
    .\New-ChrVm.ps1 -Version 7.16.2 -VMName CHR-LAB -MemoryMB 1024
#>
[CmdletBinding()]
param(
    [string]$Version,
    [string]$VMName     = 'CHR',
    [int]   $MemoryMB   = 512,
    [int]   $CpuCount   = 2,
    [string]$WanSwitch  = 'Default Switch',
    [string]$LanSwitch  = 'CHR-LAN',
    [string]$Path       = (Join-Path $env:PUBLIC 'Documents\Hyper-V\CHR')
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # much faster Invoke-WebRequest on Windows PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Log([string]$m) { Write-Host "[chr] $m" -ForegroundColor Cyan }

if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
    throw "VM '$VMName' already exists. Choose another -VMName or remove it first."
}

# --- 1. Version -------------------------------------------------------------
if (-not $Version) {
    Log 'Resolving latest stable RouterOS v7...'
    try {
        $raw     = (Invoke-WebRequest -UseBasicParsing 'https://upgrade.mikrotik.com/routeros/NEWESTa7.stable').Content
        $Version = ($raw -split '\s+')[0].Trim()
    } catch {
        throw "Could not resolve the latest version automatically. Pass it explicitly, e.g. -Version 7.16.2 (see https://mikrotik.com/download)."
    }
}
if ($Version -notmatch '^\d+\.\d+(\.\d+)?(rc\d+|beta\d+)?$') { throw "Unexpected version string: '$Version'" }
Log "RouterOS version: $Version"

# --- 2. Download & unpack ---------------------------------------------------
$vmDir = Join-Path $Path $VMName
New-Item -ItemType Directory -Force -Path $vmDir | Out-Null

$zipName = "chr-$Version.vhdx.zip"
$zipPath = Join-Path $vmDir $zipName
$url     = "https://download.mikrotik.com/routeros/$Version/$zipName"

if (-not (Test-Path $zipPath)) {
    Log "Downloading $url"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zipPath
}
Log 'Unpacking image...'
Expand-Archive -Path $zipPath -DestinationPath $vmDir -Force
$vhdx = Get-ChildItem -Path $vmDir -Filter '*.vhdx' | Select-Object -First 1
if (-not $vhdx) { throw "No .vhdx found in $zipPath" }

# Keep a pristine copy; the VM uses its own disk
$disk = Join-Path $vmDir "$VMName.vhdx"
if (-not (Test-Path $disk)) { Copy-Item $vhdx.FullName $disk }

# --- 3. Switches ------------------------------------------------------------
if (-not (Get-VMSwitch -Name $WanSwitch -ErrorAction SilentlyContinue)) {
    throw "WAN switch '$WanSwitch' not found. Existing switches: $((Get-VMSwitch).Name -join ', ')"
}
if (-not (Get-VMSwitch -Name $LanSwitch -ErrorAction SilentlyContinue)) {
    Log "Creating private switch '$LanSwitch'"
    New-VMSwitch -Name $LanSwitch -SwitchType Private | Out-Null
}

# --- 4. VM ------------------------------------------------------------------
Log "Creating VM '$VMName' (Gen 1, $MemoryMB MB, $CpuCount vCPU)"
New-VM -Name $VMName -Generation 1 -MemoryStartupBytes ($MemoryMB * 1MB) `
       -VHDPath $disk -Path $Path -SwitchName $WanSwitch | Out-Null

Set-VMMemory    -VMName $VMName -DynamicMemoryEnabled $false
Set-VMProcessor -VMName $VMName -Count $CpuCount
Set-VM          -Name   $VMName -AutomaticCheckpointsEnabled $false -CheckpointType Standard

# Rename first NIC for clarity, add LAN NIC
Get-VMNetworkAdapter -VMName $VMName | Rename-VMNetworkAdapter -NewName 'ether1-WAN'
Add-VMNetworkAdapter -VMName $VMName -Name 'ether2-LAN' -SwitchName $LanSwitch
# Needed if you later bridge VLANs / run multiple MACs through the router
Get-VMNetworkAdapter -VMName $VMName | Set-VMNetworkAdapter -MacAddressSpoofing On

# --- 5. Start ---------------------------------------------------------------
Start-VM -Name $VMName
Log "VM '$VMName' started."
Log "Console:  vmconnect.exe localhost $VMName"
Log 'Login:    admin / (empty password) - RouterOS will ask you to set a new one.'
Log 'Next:     see chr\README.md for the base router config.'
