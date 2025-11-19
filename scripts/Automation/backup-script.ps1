# Automated Backup Script
param(
    [string]$SourcePath = "C:\ImportantData",
    [string]$BackupPath = "D:\Backups"
)

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFolder = Join-Path $BackupPath "Backup_$timestamp"

try {
    Write-Host "Starting backup from $SourcePath to $backupFolder"
    New-Item -ItemType Directory -Path $backupFolder -Force
    Write-Host "Backup folder created: $backupFolder" -ForegroundColor Green
}
catch {
    Write-Error "Backup failed: $_"
}