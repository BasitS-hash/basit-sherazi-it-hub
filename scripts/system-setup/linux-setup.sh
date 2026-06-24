#!/usr/bin/env bash
# =============================================================================
# linux-setup.sh — Provision a new Linux workstation or server
# =============================================================================
# Usage:
#   sudo bash linux-setup.sh [OPTIONS]
#
# Options:
#   --tools        Install common IT/sysadmin tools via apt/dnf/yum
#   --no-prompt    Skip confirmation prompts (for CI/automation)
#   --help         Show this help message
#
# Requirements: Bash 4+, sudo privileges
# Tested on: Ubuntu 22.04, Debian 12, RHEL 9, Rocky Linux 9
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

# ── Defaults ──────────────────────────────────────────────────────────────────
INSTALL_TOOLS=false
NO_PROMPT=false
IT_BASE="${HOME}/it-tools"

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
  grep '^# ' "$0" | sed 's/^# //'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tools)      INSTALL_TOOLS=true ;;
    --no-prompt)  NO_PROMPT=true ;;
    --help|-h)    usage ;;
    *) die "Unknown option: $1. Run with --help for usage." ;;
  esac
  shift
done

# ── Privilege check ───────────────────────────────────────────────────────────
if [[ "${EUID:-$(id -u)}" -ne 0 ]] && [[ "${INSTALL_TOOLS}" == true ]]; then
  die "Run with sudo when using --tools (package installation requires root)."
fi

# ── Confirmation ──────────────────────────────────────────────────────────────
if [[ "${NO_PROMPT}" == false ]]; then
  echo ""
  echo "This script will:"
  echo "  1. Create the IT tools directory structure at ${IT_BASE}"
  [[ "${INSTALL_TOOLS}" == true ]] && echo "  2. Install common sysadmin packages"
  echo ""
  read -r -p "Continue? [y/N] " answer
  [[ "${answer,,}" == "y" ]] || { info "Aborted."; exit 0; }
fi

# ── Directory structure ───────────────────────────────────────────────────────
info "Creating IT tools directory structure at ${IT_BASE} ..."
mkdir -p "${IT_BASE}"/{scripts,backups,logs,configs,temp}
chmod 750 "${IT_BASE}"
info "Directories created."

# ── Package installation ──────────────────────────────────────────────────────
install_packages() {
  local pkgs=(curl wget git vim htop net-tools nmap rsync unzip jq)

  if command -v apt-get &>/dev/null; then
    info "Detected apt — updating package index..."
    apt-get update -qq
    apt-get install -y "${pkgs[@]}"
  elif command -v dnf &>/dev/null; then
    info "Detected dnf — installing packages..."
    dnf install -y "${pkgs[@]}"
  elif command -v yum &>/dev/null; then
    info "Detected yum — installing packages..."
    yum install -y "${pkgs[@]}"
  else
    warn "No supported package manager found (apt/dnf/yum). Skipping tool install."
  fi
}

if [[ "${INSTALL_TOOLS}" == true ]]; then
  info "Installing common IT tools..."
  install_packages
  info "Tools installed."
fi

# ── Shell hardening hints ─────────────────────────────────────────────────────
PROFILE="${HOME}/.bashrc"
ALIAS_BLOCK="# IT Hub aliases
alias ll='ls -lah'
alias grep='grep --color=auto'
alias ..='cd ..'
alias update='sudo apt-get update && sudo apt-get upgrade -y 2>/dev/null || sudo dnf upgrade -y 2>/dev/null || true'"

if ! grep -q "IT Hub aliases" "${PROFILE}" 2>/dev/null; then
  info "Adding convenience aliases to ${PROFILE} ..."
  printf '\n%s\n' "${ALIAS_BLOCK}" >> "${PROFILE}"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
info "=== Linux setup complete ==="
info "IT tools directory : ${IT_BASE}"
info "Logs location      : ${IT_BASE}/logs"
info "Next steps:"
echo "  - Review config-templates/ and copy relevant configs to ${IT_BASE}/configs/"
echo "  - Run scripts/security/security-hardening-check.sh to assess system posture"
echo "  - Run scripts/Automation/mac-backup.sh (or set up cron) for backups"
