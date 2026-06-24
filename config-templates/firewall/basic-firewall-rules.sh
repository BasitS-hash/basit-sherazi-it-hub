#!/usr/bin/env bash
# =============================================================================
# basic-firewall-rules.sh — Parameterized iptables hardening template
# =============================================================================
# Usage:
#   sudo bash basic-firewall-rules.sh [OPTIONS]
#
# Options:
#   --ssh-port  <port>     SSH port to allow (default: 22)
#   --allow-http           Allow inbound TCP port 80
#   --allow-https          Allow inbound TCP port 443
#   --extra-tcp <port>     Allow an additional TCP port
#   --dry-run              Print rules without applying them
#   --help                 Show this help message
#
# WARNING: This script FLUSHES all existing iptables rules.
#          On a live server, this will drop active connections.
#          Test in a non-production environment first.
#
# Requirements: bash 4+, iptables, root privileges
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
SSH_PORT=22
ALLOW_HTTP=false
ALLOW_HTTPS=false
EXTRA_TCP=""
DRY_RUN=false

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
  grep '^# ' "$0" | sed 's/^# //'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-port)    SSH_PORT="${2:?'--ssh-port requires a port number'}"; shift ;;
    --allow-http)  ALLOW_HTTP=true ;;
    --allow-https) ALLOW_HTTPS=true ;;
    --extra-tcp)   EXTRA_TCP="${2:?'--extra-tcp requires a port number'}"; shift ;;
    --dry-run)     DRY_RUN=true ;;
    --help|-h)     usage ;;
    *) die "Unknown option: $1. Run with --help for usage." ;;
  esac
  shift
done

# ── Privilege check ───────────────────────────────────────────────────────────
[[ "${EUID:-$(id -u)}" -eq 0 ]] || die "This script must be run as root."
command -v iptables &>/dev/null || die "iptables is not installed."

# ── Dry-run wrapper ───────────────────────────────────────────────────────────
IPT="iptables"
if [[ "${DRY_RUN}" == true ]]; then
  warn "DRY RUN — rules will be printed, not applied."
  IPT="echo iptables"
fi

# ── Safety warning ────────────────────────────────────────────────────────────
warn "This will FLUSH all existing iptables rules and replace them."
warn "Existing SSH sessions will be preserved (ESTABLISHED connections are allowed)."
warn "Press Ctrl-C within 5 seconds to abort..."
sleep 5

# ── Apply rules ───────────────────────────────────────────────────────────────
info "Flushing existing rules..."
${IPT} -F
${IPT} -X
${IPT} -t nat -F
${IPT} -t nat -X
${IPT} -t mangle -F
${IPT} -t mangle -X

info "Setting default policies (INPUT/FORWARD DROP, OUTPUT ACCEPT)..."
${IPT} -P INPUT DROP
${IPT} -P FORWARD DROP
${IPT} -P OUTPUT ACCEPT

info "Allowing loopback..."
${IPT} -A INPUT  -i lo -j ACCEPT
${IPT} -A OUTPUT -o lo -j ACCEPT

info "Allowing established/related connections..."
${IPT} -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

info "Allowing SSH on port ${SSH_PORT}..."
${IPT} -A INPUT -p tcp --dport "${SSH_PORT}" -m conntrack --ctstate NEW -j ACCEPT

if [[ "${ALLOW_HTTP}" == true ]]; then
  info "Allowing HTTP (port 80)..."
  ${IPT} -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
fi

if [[ "${ALLOW_HTTPS}" == true ]]; then
  info "Allowing HTTPS (port 443)..."
  ${IPT} -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT
fi

if [[ -n "${EXTRA_TCP}" ]]; then
  info "Allowing extra TCP port ${EXTRA_TCP}..."
  ${IPT} -A INPUT -p tcp --dport "${EXTRA_TCP}" -m conntrack --ctstate NEW -j ACCEPT
fi

info "Allowing ICMP ping (rate-limited)..."
${IPT} -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/min -j ACCEPT

info "Logging dropped packets (rate-limited to prevent log flooding)..."
${IPT} -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables-DROP: " --log-level 4

# ── Persist rules ─────────────────────────────────────────────────────────────
if [[ "${DRY_RUN}" == false ]]; then
  if command -v iptables-save &>/dev/null; then
    SAVE_FILE="/etc/iptables/rules.v4"
    mkdir -p "$(dirname "${SAVE_FILE}")"
    iptables-save > "${SAVE_FILE}"
    info "Rules saved to ${SAVE_FILE}"
    info "To restore on boot: apt install iptables-persistent  OR  add to rc.local"
  else
    warn "iptables-save not found — rules are active but will NOT persist after reboot."
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
info "=== Firewall rules applied ==="
[[ "${DRY_RUN}" == false ]] && iptables -L -n -v --line-numbers || true
echo ""
warn "Review and test these rules before deploying to production."
warn "Ensure your SSH port (${SSH_PORT}) is accessible before ending your session."
