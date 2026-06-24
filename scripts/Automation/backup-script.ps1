#Requires -Version 5.1
<#
.SYNOPSIS
    Robocopy-based timestamped backup for Windows systems.

.DESCRIPTION
    Creates a new timestamped snapshot backup from a source directory to a
    destination base directory using Robocopy. Old snapshots are never deleted
    automatically — monitor disk usage and prune manually.

.PARAMETER SourcePath
    Path to the directory you want to back up.

.PARAMETER BackupPath
    Base destination directory. A timestamped subdirectory is created inside.

.PARAMETER DryRun
    Show what Robocopy would copy without actually copying (uses /L flag).

.PARAMETER SkipConfirm
    Skip the confirmation prompt (for Task Scheduler / automation).

.EXAMPLE
    .\backup-script.ps1 -SourcePath C:\ImportantData -BackupPath D:\Backups
    .\backup-script.ps1 -SourcePath C:\Users\Me\Documents -BackupPath \\NAS\Backups -DryRun

.NOTES
    Requires PowerShell 5.1+ and Robocopy (included in all modern Windows versions).
    Robocopy exit codes 0-7 are considered success (0=no change, 1=copied, etc.).
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$BackupPath,

    [switch]$DryRun,
    [switch]$SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# ── Helpers ───────────────────────────────────────────────────────────────────
function Write-Info { param([string]$Msg) Write-Information "[INFO]  $Msg" }
function Write-Warn { param([string]$Msg) Write-Warning "[WARN]  $Msg" }
function Write-Fail { param([string]$Msg) Write-Error "[ERROR] $Msg" }

# ── Build destination ─────────────────────────────────────────────────────────
$timestamp    = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupFolder = Join-Path $BackupPath "backup_$timestamp"
$logFile      = Join-Path $BackupPath "backup_${timestamp}.log"

# ── Confirmation ──────────────────────────────────────────────────────────────
Write-Information ""
Write-Info "=== Windows Backup Utility ==="
Write-Info "Source      : $SourcePath"
Write-Info "Destination : $backupFolder"
if ($DryRun) { Write-Warn "DRY RUN — no files will be copied." }
Write-Information ""

if (-not $SkipConfirm -and -not $DryRun) {
    $answer = Read-Host "Start backup? [y/N]"
    if ($answer -notmatch '^[Yy]$') {
        Write-Info "Aborted."
        exit 0
    }
}

# ── Create destination ────────────────────────────────────────────────────────
if (-not $DryRun) {
    New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
}

# ── Robocopy ──────────────────────────────────────────────────────────────────
# Flags:
#   /E      - copy subdirectories including empty ones
#   /COPYALL- copy all file info (data, attributes, timestamps, ACLs, owner, audit)
#   /R:3    - retry 3 times on failed copy
#   /W:5    - wait 5 seconds between retries
#   /NP     - no progress percentage (cleaner log output)
#   /LOG    - write output to log file
#   /L      - list only (dry run)
$roboArgs = @($SourcePath, $backupFolder, '/E', '/COPYALL', '/R:3', '/W:5', '/NP', "/LOG:$logFile")
if ($DryRun) { $roboArgs += '/L' }

Write-Info "Running Robocopy..."
try {
    $proc = Start-Process -FilePath 'robocopy' -ArgumentList $roboArgs -Wait -PassThru -NoNewWindow
    # Robocopy exit codes 0-7 are informational (success variants); 8+ are errors
    if ($proc.ExitCode -ge 8) {
        Write-Fail "Robocopy reported errors (exit code $($proc.ExitCode)). Check: $logFile"
        exit 1
    }
} catch {
    Write-Fail "Failed to run Robocopy: $_"
    exit 1
}

# ── Write metadata ────────────────────────────────────────────────────────────
if (-not $DryRun) {
    $metaFile = Join-Path $backupFolder 'backup_info.txt'
    @"
Backup completed : $timestamp
Source           : $SourcePath
Destination      : $backupFolder
Host             : $($env:COMPUTERNAME)
User             : $($env:USERNAME)
Robocopy log     : $logFile
"@ | Set-Content -Path $metaFile -Encoding UTF8
}

Write-Information ""
Write-Info "=== Backup complete ==="
Write-Info "Snapshot : $backupFolder"
Write-Info "Log file : $logFile"
