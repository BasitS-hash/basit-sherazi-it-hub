#!/usr/bin/env bash
# =============================================================================
# network-test.sh — Network connectivity and diagnostics tool
# =============================================================================
# Usage:
#   bash network-test.sh [OPTIONS]
#
# Options:
#   --host <ip_or_hostname>   Host to ping for connectivity check (default: 8.8.8.8)
#   --dns  <hostname>         Hostname to resolve for DNS check (default: google.com)
#   --ports <port_list>       Comma-separated ports to check LISTENING (default: 22,80,443)
#   --help                    Show this help message
#
# Examples:
#   bash network-test.sh
#   bash network-test.sh --host 1.1.1.1 --dns example.com
#   bash network-test.sh --ports 22,80,443,8080,3389
#
# Requirements: bash 4+, standard networking tools (ping, dig/nslookup, ss/netstat)
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
section() { echo -e "\n${CYAN}=== $* ===${NC}"; }

# ── Defaults ──────────────────────────────────────────────────────────────────
PING_HOST="8.8.8.8"
DNS_HOST="google.com"
CHECK_PORTS="22,80,443"
OVERALL_STATUS=0

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
  grep '^# ' "$0" | sed 's/^# //'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)   PING_HOST="${2:?'--host requires a value'}"; shift ;;
    --dns)    DNS_HOST="${2:?'--dns requires a value'}"; shift ;;
    --ports)  CHECK_PORTS="${2:?'--ports requires a value'}"; shift ;;
    --help|-h) usage ;;
    *) error "Unknown option: $1"; usage ;;
  esac
  shift
done

# ── Helper: pass/fail printer ─────────────────────────────────────────────────
pass() { echo -e "  ${GREEN}PASS${NC}  $*"; }
fail() { echo -e "  ${RED}FAIL${NC}  $*"; OVERALL_STATUS=1; }
maybe() { echo -e "  ${YELLOW}SKIP${NC}  $*"; }

# ── 1. Basic connectivity ─────────────────────────────────────────────────────
section "Internet Connectivity (ping ${PING_HOST})"
if ping -c 3 -W 2 "${PING_HOST}" &>/dev/null; then
  RTT="$(ping -c 3 -W 2 "${PING_HOST}" 2>/dev/null | grep -E 'rtt|round-trip' | grep -Eo '[0-9]+\.[0-9]+' | head -1)"
  pass "Reached ${PING_HOST}  (avg RTT: ${RTT:-unknown} ms)"
else
  fail "Cannot reach ${PING_HOST} — check default gateway / ISP"
fi

# ── 2. DNS resolution ─────────────────────────────────────────────────────────
section "DNS Resolution (resolving ${DNS_HOST})"
if command -v dig &>/dev/null; then
  RESOLVED="$(dig +short "${DNS_HOST}" A 2>/dev/null | head -1)"
elif command -v nslookup &>/dev/null; then
  RESOLVED="$(nslookup "${DNS_HOST}" 2>/dev/null | awk '/^Address:/{last=$2}END{print last}')"
else
  RESOLVED=""
  maybe "Neither dig nor nslookup found — skipping DNS check"
fi

if [[ -n "${RESOLVED}" ]]; then
  pass "${DNS_HOST} resolved to ${RESOLVED}"
else
  fail "Failed to resolve ${DNS_HOST}"
fi

# ── 3. Network interface listing ──────────────────────────────────────────────
section "Network Interfaces"
if command -v ip &>/dev/null; then
  ip -brief addr show | while IFS= read -r line; do
    echo "  ${line}"
  done
elif command -v ifconfig &>/dev/null; then
  ifconfig | grep -E "^[a-z]|inet " | while IFS= read -r line; do
    echo "  ${line}"
  done
fi

# ── 4. Default gateway ────────────────────────────────────────────────────────
section "Default Gateway"
if command -v ip &>/dev/null; then
  GW="$(ip route show default 2>/dev/null | awk '/default/{print $3}' | head -1)"
elif command -v route &>/dev/null; then
  # macOS
  GW="$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}' | head -1)"
else
  GW=""
fi

if [[ -n "${GW}" ]]; then
  info "Default gateway: ${GW}"
  if ping -c 2 -W 2 "${GW}" &>/dev/null; then
    pass "Gateway ${GW} is reachable"
  else
    fail "Gateway ${GW} is NOT reachable"
  fi
else
  warn "Could not determine default gateway"
fi

# ── 5. Listening port check ───────────────────────────────────────────────────
section "Listening Ports (${CHECK_PORTS})"
IFS=',' read -ra PORT_LIST <<< "${CHECK_PORTS}"
for port in "${PORT_LIST[@]}"; do
  port="${port// /}"  # strip spaces
  if command -v ss &>/dev/null; then
    if ss -tlnp 2>/dev/null | grep -qE ":${port}\s"; then
      pass "Port ${port} is LISTENING"
    else
      warn "Port ${port} is NOT listening (may be expected)"
    fi
  elif command -v netstat &>/dev/null; then
    if netstat -an 2>/dev/null | grep -qE "\.${port}\s.*LISTEN|:${port}\s.*LISTEN"; then
      pass "Port ${port} is LISTENING"
    else
      warn "Port ${port} is NOT listening"
    fi
  else
    maybe "ss/netstat not found — skipping port ${port} check"
  fi
done

# ── 6. Summary ────────────────────────────────────────────────────────────────
section "Summary"
if [[ "${OVERALL_STATUS}" -eq 0 ]]; then
  info "All critical checks passed."
else
  warn "One or more checks failed — review output above."
fi
echo ""
exit "${OVERALL_STATUS}"
