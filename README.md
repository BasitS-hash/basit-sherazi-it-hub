# Basit Sherazi — IT Starter Hub

[![ShellCheck](https://github.com/BasitS-hash/basit-sherazi-it-hub/actions/workflows/ci.yml/badge.svg)](https://github.com/BasitS-hash/basit-sherazi-it-hub/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A production-ready IT/sysadmin starter kit with working, parameterized scripts for system provisioning, backups, network diagnostics, and security hardening — across Linux, macOS, and Windows.

---

## Contents

```
.
├── scripts/
│   ├── system-setup/          # OS provisioning (Linux, macOS, Windows)
│   ├── Automation/            # Backup automation (bash + PowerShell)
│   ├── network/               # Network diagnostics
│   └── security/              # Security hardening checks
├── config-templates/
│   └── firewall/              # iptables firewall rule templates
├── security/
│   └── security-checklist.md  # CIS-inspired hardening checklist
├── docs/
│   └── setup-guide.md         # Getting started guide
└── backups/                   # Local backup staging area (git-ignored)
```

---

## Script Catalog

| Script | Platform | Purpose | Usage |
|--------|----------|---------|-------|
| `scripts/system-setup/linux-setup.sh` | Linux | Provision a new Linux workstation or server: create directory structure, install common tools, configure shell | `sudo bash linux-setup.sh [--tools] [--no-prompt]` |
| `scripts/system-setup/macos-setup.sh` | macOS | Provision a new macOS machine: create directories, install Homebrew + packages, configure defaults | `bash macos-setup.sh [--tools] [--no-prompt]` |
| `scripts/system-setup/windows-setup.ps1` | Windows | Provision a new Windows system: system info, install Chocolatey + packages, configure Execution Policy | `.\windows-setup.ps1 [-InstallTools] [-SkipConfirm]` |
| `scripts/Automation/mac-backup.sh` | macOS/Linux | Rsync-based backup to a configurable destination directory with timestamped snapshots | `bash mac-backup.sh -s ~/Documents -d /Volumes/Backup` |
| `scripts/Automation/backup-script.ps1` | Windows | Robocopy-based backup with timestamped snapshot folders and error reporting | `.\backup-script.ps1 -SourcePath C:\Data -BackupPath D:\Backups` |
| `scripts/network/network-test.sh` | Linux/macOS | Network connectivity: ping gateway, DNS resolution, port checks, interface listing | `bash network-test.sh [--host 1.1.1.1] [--ports 22,80,443]` |
| `scripts/security/security-hardening-check.sh` | Linux | Automated CIS Benchmark-inspired checks: SSH config, world-writable files, SUID binaries, password policy | `sudo bash security-hardening-check.sh [--report]` |
| `config-templates/firewall/basic-firewall-rules.sh` | Linux | Parameterized iptables template: sets sane defaults, allows SSH/HTTP/HTTPS | `sudo bash basic-firewall-rules.sh [--ssh-port 22]` |

---

## Prerequisites

| Tool | Minimum Version | Required For |
|------|----------------|-------------|
| Bash | 4.0+ | All `.sh` scripts |
| PowerShell | 5.1+ (or PS Core 7+) | `.ps1` scripts |
| rsync | any | `mac-backup.sh` |
| iptables | any | `basic-firewall-rules.sh` |
| Homebrew | any | `macos-setup.sh --tools` |
| Chocolatey | any | `windows-setup.ps1 -InstallTools` |

---

## Quick Start

```bash
# 1. Clone
git clone https://github.com/BasitS-hash/basit-sherazi-it-hub.git
cd basit-sherazi-it-hub

# 2. Linux: provision a new machine
sudo bash scripts/system-setup/linux-setup.sh --tools

# 3. macOS: provision a new machine
bash scripts/system-setup/macos-setup.sh --tools

# 4. Run a backup (Linux/macOS)
bash scripts/Automation/mac-backup.sh -s ~/Documents -d ~/Backups

# 5. Run security hardening check
sudo bash scripts/security/security-hardening-check.sh --report
```

**Windows (PowerShell as Administrator):**
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\scripts\system-setup\windows-setup.ps1 -InstallTools
.\scripts\Automation\backup-script.ps1 -SourcePath C:\ImportantData -BackupPath D:\Backups
```

---

## Safety Notes

- **Review every script before running as root/Administrator.** These scripts create directories, install packages, and modify firewall rules.
- **`basic-firewall-rules.sh` flushes all existing iptables rules.** On a live server, this may drop active connections. Test in a non-production environment first or add `--dry-run` to preview.
- **Backup scripts do not delete old snapshots.** Monitor disk usage and prune old backups manually (or add a retention policy).
- **No secrets are committed.** Use a `.env` file (git-ignored) or a secrets manager for credentials.

---

## Contributing

1. Fork the repo and create a feature branch.
2. Run ShellCheck (`shellcheck scripts/**/*.sh`) before committing.
3. Run PSScriptAnalyzer (`Invoke-ScriptAnalyzer -Path .\scripts\`) for PowerShell changes.
4. Open a pull request with a description of what changed and why.

---

## License

MIT — see [LICENSE](LICENSE).
