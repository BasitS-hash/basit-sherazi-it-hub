#!/usr/bin/env bash
# =============================================================================
# macos-setup.sh — Provision a new macOS machine for IT/sysadmin work
# =============================================================================
# Usage:
#   bash macos-setup.sh [OPTIONS]
#
# Options:
#   --tools        Install Homebrew + common IT packages (curl, nmap, rsync…)
#   --no-prompt    Skip confirmation prompts (for CI/automation)
#   --help         Show this help message
#
# Requirements: Bash 4+, macOS 12+
# Note: Homebrew installation requires interactive approval (password prompt).
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { error "$*"; exit 1; }

# ── Defaults ──────────────────────────────────────────────────────────────────
INSTALL_TOOLS=false
NO_PROMPT=false
IT_BASE="${HOME}/it-tools"

BREW_PACKAGES=(
  curl wget git vim htop nmap rsync jq shellcheck
  gnu-sed coreutils
)

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

# ── Must not run as root ──────────────────────────────────────────────────────
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  die "Do NOT run this script as root on macOS. Homebrew refuses to run as root."
fi

# ── OS check ─────────────────────────────────────────────────────────────────
if [[ "$(uname -s)" != "Darwin" ]]; then
  die "This script is for macOS only. Use linux-setup.sh on Linux."
fi

# ── Confirmation ──────────────────────────────────────────────────────────────
if [[ "${NO_PROMPT}" == false ]]; then
  echo ""
  echo "This script will:"
  echo "  1. Create the IT tools directory structure at ${IT_BASE}"
  [[ "${INSTALL_TOOLS}" == true ]] && echo "  2. Install Homebrew (if missing) and: ${BREW_PACKAGES[*]}"
  echo ""
  read -r -p "Continue? [y/N] " answer
  [[ "${answer,,}" == "y" ]] || { info "Aborted."; exit 0; }
fi

# ── Directory structure ───────────────────────────────────────────────────────
info "Creating IT tools directory structure at ${IT_BASE} ..."
mkdir -p "${IT_BASE}"/{scripts,backups,logs,configs,temp}
info "Directories created."

# ── Homebrew + packages ───────────────────────────────────────────────────────
if [[ "${INSTALL_TOOLS}" == true ]]; then
  if ! command -v brew &>/dev/null; then
    info "Homebrew not found — installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for the current session (Apple Silicon path)
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  else
    info "Homebrew already installed — skipping install."
  fi

  info "Installing packages: ${BREW_PACKAGES[*]}"
  brew install "${BREW_PACKAGES[@]}" || warn "Some packages failed to install — check brew output above."
fi

# ── macOS defaults (sane, non-destructive) ────────────────────────────────────
info "Applying sane macOS defaults..."
# Show all filename extensions in Finder
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Disable crash reporter UI (still logs)
defaults write com.apple.CrashReporter DialogType -string "none"
# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true

# ── Shell convenience ─────────────────────────────────────────────────────────
PROFILE="${HOME}/.zshrc"
ALIAS_BLOCK="# IT Hub aliases
alias ll='ls -lah'
alias grep='grep --color=auto'
alias ..='cd ..'
alias flushdns='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'"

if ! grep -q "IT Hub aliases" "${PROFILE}" 2>/dev/null; then
  info "Adding convenience aliases to ${PROFILE} ..."
  printf '\n%s\n' "${ALIAS_BLOCK}" >> "${PROFILE}"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
info "=== macOS setup complete ==="
info "IT tools directory : ${IT_BASE}"
info "Logs location      : ${IT_BASE}/logs"
info "Next steps:"
echo "  - Source your shell: source ${PROFILE}"
echo "  - Run scripts/Automation/mac-backup.sh to create your first backup"
echo "  - Review config-templates/ and copy relevant configs"
