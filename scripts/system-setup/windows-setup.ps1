#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Provision a new Windows system for IT/sysadmin work.

.DESCRIPTION
    Performs initial system configuration:
    - Displays OS information
    - Optionally installs Chocolatey and common IT tools
    - Creates a local IT tools directory structure
    - Reports execution policy

.PARAMETER InstallTools
    Install Chocolatey package manager and common IT packages.

.PARAMETER SkipConfirm
    Skip all confirmation prompts (for automation/CI).

.EXAMPLE
    .\windows-setup.ps1
    .\windows-setup.ps1 -InstallTools
    .\windows-setup.ps1 -InstallTools -SkipConfirm

.NOTES
    Requires PowerShell 5.1+ or PowerShell Core 7+
    Must be run as Administrator.
#>

[CmdletBinding()]
param (
    [switch]$InstallTools,
    [switch]$SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# ── Helpers ───────────────────────────────────────────────────────────────────
function Write-Step { param([string]$Msg) Write-Information "[STEP]  $Msg" }
function Write-Info { param([string]$Msg) Write-Information "[INFO]  $Msg" }
function Write-Warn { param([string]$Msg) Write-Warning "[WARN]  $Msg" }
function Write-Fail { param([string]$Msg) Write-Error "[ERROR] $Msg" }

# ── Confirmation ──────────────────────────────────────────────────────────────
if (-not $SkipConfirm) {
    Write-Information ""
    Write-Information "This script will:"
    Write-Information "  1. Display system information"
    Write-Information "  2. Create IT tools directory structure"
    if ($InstallTools) {
        Write-Information "  3. Install Chocolatey and common IT packages"
    }
    Write-Information ""
    $answer = Read-Host "Continue? [y/N]"
    if ($answer -notmatch '^[Yy]$') {
        Write-Info "Aborted."
        exit 0
    }
}

# ── 1. System information ─────────────────────────────────────────────────────
Write-Step "Collecting system information..."
try {
    $os  = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $mem = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)

    Write-Info "OS      : $($os.Caption) Build $($os.BuildNumber)"
    Write-Info "CPU     : $($cpu.Name)"
    Write-Info "RAM     : ${mem} GB"
    Write-Info "Hostname: $($env:COMPUTERNAME)"
    Write-Info "User    : $($env:USERNAME)"
} catch {
    Write-Warn "Could not retrieve full system info: $_"
}

# ── 2. Execution policy ───────────────────────────────────────────────────────
Write-Step "Checking execution policy..."
$policy = Get-ExecutionPolicy -Scope CurrentUser
Write-Info "Current user execution policy: $policy"
if ($policy -eq 'Restricted') {
    Write-Warn "Execution policy is Restricted — scripts may not run."
    Write-Warn "To allow scripts: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
}

# ── 3. Directory structure ────────────────────────────────────────────────────
Write-Step "Creating IT tools directory structure..."
$ItBase = Join-Path $env:USERPROFILE 'it-tools'
$subdirs = @('scripts', 'backups', 'logs', 'configs', 'temp')
foreach ($sub in $subdirs) {
    $path = Join-Path $ItBase $sub
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Info "Created: $path"
    } else {
        Write-Info "Already exists: $path"
    }
}

# ── 4. Optional Chocolatey + packages ────────────────────────────────────────
if ($InstallTools) {
    Write-Step "Checking for Chocolatey..."
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Info "Installing Chocolatey..."
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            $chocoScript = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
            & ([scriptblock]::Create($chocoScript))
        } catch {
            Write-Fail "Failed to install Chocolatey: $_"
        }
    } else {
        Write-Info "Chocolatey already installed."
    }

    $packages = @('git', 'curl', 'vim', '7zip', 'nmap', 'wireshark', 'putty')
    Write-Step "Installing packages: $($packages -join ', ')..."
    foreach ($pkg in $packages) {
        try {
            choco install $pkg -y --no-progress 2>&1 | Out-Null
            Write-Info "Installed: $pkg"
        } catch {
            Write-Warn "Failed to install $pkg — skipping."
        }
    }
}

# ── 5. Summary ────────────────────────────────────────────────────────────────
Write-Information ""
Write-Info "=== Windows setup complete ==="
Write-Info "IT tools directory: $ItBase"
Write-Information ""
Write-Information "Next steps:"
Write-Information "  - Run .\scripts\Automation\backup-script.ps1 to configure backups"
Write-Information "  - Review config-templates\ and copy relevant configs"
Write-Information "  - Run a security scan with Windows Defender or your EDR"
