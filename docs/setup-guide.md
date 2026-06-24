# IT Starter Hub — Setup Guide

## Prerequisites

| Tool | Minimum Version | Platform |
|------|----------------|----------|
| Bash | 4.0+ | Linux, macOS |
| PowerShell | 5.1+ (or Core 7+) | Windows |
| rsync | any | Linux/macOS (backups) |
| iptables | any | Linux (firewall) |
| Homebrew | any | macOS (optional tools) |
| Chocolatey | any | Windows (optional tools) |

---

## Linux

### 1. Provision a new machine

```bash
# Clone the repo
git clone https://github.com/BasitS-hash/basit-sherazi-it-hub.git
cd basit-sherazi-it-hub

# Basic setup (creates ~/it-tools/ directory structure)
sudo bash scripts/system-setup/linux-setup.sh

# Setup + install common tools (curl, git, nmap, rsync, jq, etc.)
sudo bash scripts/system-setup/linux-setup.sh --tools
```

### 2. Run a backup

```bash
# Preview what would be backed up (no files copied)
bash scripts/Automation/mac-backup.sh -s ~/Documents -d ~/Backups --dry-run

# Run the actual backup
bash scripts/Automation/mac-backup.sh -s ~/Documents -d ~/Backups
```

### 3. Set up iptables firewall

```bash
# Preview rules without applying
sudo bash config-templates/firewall/basic-firewall-rules.sh --dry-run --allow-http --allow-https

# Apply rules (SSH on default port 22, HTTP + HTTPS)
sudo bash config-templates/firewall/basic-firewall-rules.sh --allow-http --allow-https

# Custom SSH port
sudo bash config-templates/firewall/basic-firewall-rules.sh --ssh-port 2222 --allow-https
```

### 4. Security audit

```bash
# Run hardening checks (prints pass/warn/fail to stdout)
sudo bash scripts/security/security-hardening-check.sh

# Write findings to a timestamped report file in /tmp/
sudo bash scripts/security/security-hardening-check.sh --report
```

### 5. Network diagnostics

```bash
bash scripts/network/network-test.sh
bash scripts/network/network-test.sh --host 1.1.1.1 --ports 22,80,443,8080
```

---

## macOS

```bash
# Basic setup
bash scripts/system-setup/macos-setup.sh

# Setup + install Homebrew packages (shellcheck, nmap, rsync, jq, etc.)
bash scripts/system-setup/macos-setup.sh --tools

# Backup
bash scripts/Automation/mac-backup.sh -s ~/Documents -d ~/Backups
```

---

## Windows (PowerShell as Administrator)

```powershell
# Allow script execution (first time only)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Basic setup
.\scripts\system-setup\windows-setup.ps1

# Setup + install Chocolatey + packages
.\scripts\system-setup\windows-setup.ps1 -InstallTools

# Backup (preview)
.\scripts\Automation\backup-script.ps1 -SourcePath C:\ImportantData -BackupPath D:\Backups -DryRun

# Backup (run)
.\scripts\Automation\backup-script.ps1 -SourcePath C:\ImportantData -BackupPath D:\Backups
```

---

## Automating Backups

### Linux/macOS — cron

```bash
# Edit crontab
crontab -e

# Run backup every day at 2am
0 2 * * * /bin/bash /path/to/basit-sherazi-it-hub/scripts/Automation/mac-backup.sh \
  -s "${HOME}/Documents" -d "${HOME}/Backups" --no-prompt >> /var/log/it-backup.log 2>&1
```

### Windows — Task Scheduler

```powershell
$action  = New-ScheduledTaskAction -Execute 'pwsh.exe' `
             -Argument '-NonInteractive -File C:\it-hub\scripts\Automation\backup-script.ps1 -SourcePath C:\Data -BackupPath D:\Backups -SkipConfirm'
$trigger = New-ScheduledTaskTrigger -Daily -At '2:00AM'
Register-ScheduledTask -TaskName 'IT-Hub-Backup' -Action $action -Trigger $trigger -RunLevel Highest
```

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `Permission denied` on `.sh` | Script not executable | `chmod +x script.sh` |
| `rsync: not found` | rsync missing | `sudo apt install rsync` / `brew install rsync` |
| PowerShell `execution of scripts is disabled` | Execution policy | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| iptables rules not surviving reboot | iptables-persistent missing | `sudo apt install iptables-persistent` |
| `shellcheck: not found` in CI | ShellCheck missing | add to PATH or install via package manager |
