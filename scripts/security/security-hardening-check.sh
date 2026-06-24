#!/usr/bin/env bash
# =============================================================================
# security-hardening-check.sh — CIS Benchmark-inspired Linux security audit
# =============================================================================
# Usage:
#   sudo bash security-hardening-check.sh [OPTIONS]
#
# Options:
#   --report     Write findings to a timestamped report file in /tmp/
#   --help       Show this help message
#
# Checks performed:
#   - SSH daemon configuration (root login, password auth, port)
#   - World-writable files (excluding /proc, /sys, /dev)
#   - SUID/SGID binaries outside standard system paths
#   - Accounts with empty passwords
#   - Firewall status (iptables / ufw / firewalld)
#   - Automatic security updates
#   - Core dumps disabled
#   - IPv6 forwarding disabled
#
# Requirements: bash 4+, standard Linux utilities, root privileges for full scan
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
section() { echo -e "\n${CYAN}=== $* ===${NC}"; }
pass()    { echo -e "  ${GREEN}PASS${NC}  $*"; }
fail()    { echo -e "  ${RED}FAIL${NC}  $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn()    { echo -e "  ${YELLOW}WARN${NC}  $*"; WARN_COUNT=$((WARN_COUNT + 1)); }
info()    { echo -e "        $*"; }

# ── Argument parsing ──────────────────────────────────────────────────────────
WRITE_REPORT=false
REPORT_FILE=""

usage() {
  grep '^# ' "$0" | sed 's/^# //'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report)  WRITE_REPORT=true ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1. Use --help."; exit 1 ;;
  esac
  shift
done

# ── Privilege check ───────────────────────────────────────────────────────────
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[WARN] Not running as root — some checks will be skipped."
fi

# ── Counters ──────────────────────────────────────────────────────────────────
FAIL_COUNT=0
WARN_COUNT=0
PASS_COUNT=0

# ── Tee to report if requested ────────────────────────────────────────────────
if [[ "${WRITE_REPORT}" == true ]]; then
  REPORT_FILE="/tmp/security-report-$(date '+%Y%m%d_%H%M%S').txt"
  exec > >(tee "${REPORT_FILE}") 2>&1
fi

echo ""
echo "========================================"
echo "  Linux Security Hardening Check"
echo "  Host: $(hostname)    Date: $(date)"
echo "========================================"

# ── 1. SSH configuration ──────────────────────────────────────────────────────
section "SSH Daemon Configuration"
SSHD_CONFIG="/etc/ssh/sshd_config"
if [[ -f "${SSHD_CONFIG}" ]]; then
  # Root login
  if grep -Eqi '^\s*PermitRootLogin\s+no' "${SSHD_CONFIG}"; then
    pass "PermitRootLogin no"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    fail "PermitRootLogin is not set to 'no' — root SSH login may be allowed"
    info "Fix: Set 'PermitRootLogin no' in ${SSHD_CONFIG}"
  fi

  # Password authentication
  if grep -Eqi '^\s*PasswordAuthentication\s+no' "${SSHD_CONFIG}"; then
    pass "PasswordAuthentication no"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    warn "PasswordAuthentication may be enabled — prefer key-based auth only"
    info "Fix: Set 'PasswordAuthentication no' in ${SSHD_CONFIG}"
  fi

  # Protocol version (legacy)
  if grep -Eqi '^\s*Protocol\s+1' "${SSHD_CONFIG}"; then
    fail "SSH Protocol 1 is explicitly configured — CRITICAL legacy vulnerability"
    info "Fix: Remove 'Protocol 1' or set 'Protocol 2' in ${SSHD_CONFIG}"
  else
    pass "SSH Protocol 1 not configured"
    PASS_COUNT=$((PASS_COUNT + 1))
  fi

  # X11 Forwarding
  if grep -Eqi '^\s*X11Forwarding\s+no' "${SSHD_CONFIG}"; then
    pass "X11Forwarding no"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    warn "X11Forwarding may be enabled — disable if not needed"
    info "Fix: Set 'X11Forwarding no' in ${SSHD_CONFIG}"
  fi
else
  warn "sshd_config not found at ${SSHD_CONFIG} — SSH may not be installed"
fi

# ── 2. World-writable files ───────────────────────────────────────────────────
section "World-Writable Files (excluding /proc /sys /dev)"
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  WORLD_WRITABLE="$(find / -xdev -type f -perm -0002 \
    ! -path '/proc/*' ! -path '/sys/*' ! -path '/dev/*' \
    2>/dev/null | head -20)"
  if [[ -z "${WORLD_WRITABLE}" ]]; then
    pass "No world-writable files found"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    fail "World-writable files found:"
    echo "${WORLD_WRITABLE}" | while IFS= read -r f; do info "  ${f}"; done
  fi
else
  warn "Skipped (requires root)"
fi

# ── 3. SUID/SGID binaries ─────────────────────────────────────────────────────
section "Non-Standard SUID/SGID Binaries"
STANDARD_SUID_PATHS=('/bin' '/sbin' '/usr/bin' '/usr/sbin' '/usr/lib' '/usr/libexec')
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  SUID_FILES="$(find / -xdev \( -perm -4000 -o -perm -2000 \) -type f \
    ! -path '/proc/*' ! -path '/sys/*' 2>/dev/null)"
  UNEXPECTED=""
  while IFS= read -r f; do
    IS_STANDARD=false
    for std in "${STANDARD_SUID_PATHS[@]}"; do
      [[ "${f}" == "${std}/"* ]] && IS_STANDARD=true && break
    done
    [[ "${IS_STANDARD}" == false ]] && UNEXPECTED+="${f}"$'\n'
  done <<< "${SUID_FILES}"

  if [[ -z "${UNEXPECTED}" ]]; then
    pass "No unexpected SUID/SGID binaries found"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    warn "Unexpected SUID/SGID binaries (investigate each):"
    echo "${UNEXPECTED}" | while IFS= read -r f; do [[ -n "${f}" ]] && info "  ${f}"; done
  fi
else
  warn "Skipped (requires root)"
fi

# ── 4. Empty password accounts ────────────────────────────────────────────────
section "Accounts With Empty Passwords"
if [[ "${EUID:-$(id -u)}" -eq 0 ]] && [[ -f /etc/shadow ]]; then
  EMPTY_PASS="$(awk -F: '($2 == "" || $2 == "!!" ) {print $1}' /etc/shadow | grep -v '^$' || true)"
  if [[ -z "${EMPTY_PASS}" ]]; then
    pass "No accounts with empty/locked passwords"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    fail "Accounts with empty/no password: ${EMPTY_PASS}"
    info "Fix: Set passwords or lock accounts: passwd -l <username>"
  fi
else
  warn "Skipped (requires root and /etc/shadow)"
fi

# ── 5. Firewall status ────────────────────────────────────────────────────────
section "Firewall Status"
FW_ACTIVE=false
if command -v ufw &>/dev/null; then
  UFW_STATUS="$(ufw status 2>/dev/null | head -1)"
  if echo "${UFW_STATUS}" | grep -qi 'active'; then
    pass "ufw is active"
    PASS_COUNT=$((PASS_COUNT + 1))
    FW_ACTIVE=true
  fi
fi
if command -v firewall-cmd &>/dev/null; then
  if firewall-cmd --state 2>/dev/null | grep -qi 'running'; then
    pass "firewalld is running"
    PASS_COUNT=$((PASS_COUNT + 1))
    FW_ACTIVE=true
  fi
fi
if command -v iptables &>/dev/null; then
  IPT_RULES="$(iptables -L 2>/dev/null | grep -c '^[A-Z]' || true)"
  if [[ "${IPT_RULES}" -gt 3 ]]; then   # more than the 3 default chain headers
    pass "iptables has active rules"
    PASS_COUNT=$((PASS_COUNT + 1))
    FW_ACTIVE=true
  fi
fi
if [[ "${FW_ACTIVE}" == false ]]; then
  fail "No active firewall detected (ufw/firewalld/iptables)"
  info "Fix: Enable ufw: 'ufw enable' or use config-templates/firewall/basic-firewall-rules.sh"
fi

# ── 6. Automatic updates ──────────────────────────────────────────────────────
section "Automatic Security Updates"
if command -v apt-get &>/dev/null; then
  if dpkg -l 'unattended-upgrades' &>/dev/null 2>&1; then
    pass "unattended-upgrades is installed"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    warn "unattended-upgrades not installed"
    info "Fix: apt-get install unattended-upgrades && dpkg-reconfigure -plow unattended-upgrades"
  fi
elif command -v dnf &>/dev/null; then
  if systemctl is-active --quiet dnf-automatic 2>/dev/null; then
    pass "dnf-automatic is active"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    warn "dnf-automatic not active"
    info "Fix: dnf install dnf-automatic && systemctl enable --now dnf-automatic.timer"
  fi
else
  warn "Unknown package manager — cannot check auto-update status"
fi

# ── 7. Core dumps ─────────────────────────────────────────────────────────────
section "Core Dumps"
CORE_LIMIT="$(ulimit -c 2>/dev/null || echo 'unknown')"
if [[ "${CORE_LIMIT}" == "0" ]]; then
  pass "Core dumps are disabled (ulimit -c = 0)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  warn "Core dumps may be enabled (ulimit -c = ${CORE_LIMIT}) — can expose sensitive data"
  info "Fix: Add 'ulimit -c 0' to /etc/profile or set 'hard core 0' in /etc/security/limits.conf"
fi

# ── 8. IPv6 forwarding ────────────────────────────────────────────────────────
section "IPv6 Forwarding"
IPV6_FWD="$(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null || echo 'unavailable')"
if [[ "${IPV6_FWD}" == "0" ]]; then
  pass "IPv6 forwarding is disabled"
  PASS_COUNT=$((PASS_COUNT + 1))
elif [[ "${IPV6_FWD}" == "unavailable" ]]; then
  warn "Could not read net.ipv6.conf.all.forwarding (IPv6 may not be compiled in)"
else
  warn "IPv6 forwarding is enabled (${IPV6_FWD}) — disable if this is not a router"
  info "Fix: sysctl -w net.ipv6.conf.all.forwarding=0"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "  SUMMARY"
echo "========================================"
echo -e "  ${GREEN}PASS${NC}: ${PASS_COUNT}"
echo -e "  ${YELLOW}WARN${NC}: ${WARN_COUNT}"
echo -e "  ${RED}FAIL${NC}: ${FAIL_COUNT}"
echo ""
if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  echo -e "  ${RED}Action required — address FAIL items before production deployment.${NC}"
elif [[ "${WARN_COUNT}" -gt 0 ]]; then
  echo -e "  ${YELLOW}Review WARN items — they represent elevated risk.${NC}"
else
  echo -e "  ${GREEN}System passed all checks.${NC}"
fi
echo ""

if [[ "${WRITE_REPORT}" == true ]] && [[ -n "${REPORT_FILE}" ]]; then
  echo "Report written to: ${REPORT_FILE}"
fi

exit "${FAIL_COUNT}"
