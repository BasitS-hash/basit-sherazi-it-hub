#!/usr/bin/env bash
# =============================================================================
# mac-backup.sh — Rsync-based timestamped backup for Linux/macOS
# =============================================================================
# Usage:
#   bash mac-backup.sh -s <source_dir> -d <dest_dir> [OPTIONS]
#
# Options:
#   -s, --source <path>    Directory to back up (required)
#   -d, --dest   <path>    Destination base directory (required)
#   --dry-run              Show what would be copied without copying
#   --no-prompt            Skip confirmation (for cron/automation)
#   --help                 Show this help message
#
# Example:
#   bash mac-backup.sh -s ~/Documents -d /Volumes/ExternalDrive/Backups
#   bash mac-backup.sh -s /etc -d /mnt/nas/backups --dry-run
#
# Requirements: bash 4+, rsync
# Each run creates a NEW timestamped snapshot — old snapshots are never deleted.
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
SOURCE_DIR=""
DEST_DIR=""
DRY_RUN=false
NO_PROMPT=false

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
  grep '^# ' "$0" | sed 's/^# //'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--source)  SOURCE_DIR="${2:?'--source requires a path'}"; shift ;;
    -d|--dest)    DEST_DIR="${2:?'--dest requires a path'}"; shift ;;
    --dry-run)    DRY_RUN=true ;;
    --no-prompt)  NO_PROMPT=true ;;
    --help|-h)    usage ;;
    *) die "Unknown option: $1. Run with --help for usage." ;;
  esac
  shift
done

# ── Validation ────────────────────────────────────────────────────────────────
[[ -n "${SOURCE_DIR}" ]] || die "Source directory is required (-s <path>)."
[[ -n "${DEST_DIR}" ]]   || die "Destination directory is required (-d <path>)."
[[ -d "${SOURCE_DIR}" ]] || die "Source directory does not exist: ${SOURCE_DIR}"

command -v rsync &>/dev/null || die "rsync is not installed. Install it and retry."

# ── Build destination path ────────────────────────────────────────────────────
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
BACKUP_DEST="${DEST_DIR}/backup_${TIMESTAMP}"
LOG_FILE="${DEST_DIR}/backup_${TIMESTAMP}.log"

# ── Confirmation ──────────────────────────────────────────────────────────────
echo ""
info "=== macOS/Linux Backup Utility ==="
info "Source      : ${SOURCE_DIR}"
info "Destination : ${BACKUP_DEST}"
[[ "${DRY_RUN}" == true ]] && warn "DRY RUN — no files will be copied."
echo ""

if [[ "${NO_PROMPT}" == false ]] && [[ "${DRY_RUN}" == false ]]; then
  read -r -p "Start backup? [y/N] " answer
  [[ "${answer,,}" == "y" ]] || { info "Aborted."; exit 0; }
fi

# ── Run rsync ─────────────────────────────────────────────────────────────────
RSYNC_OPTS=(
  --archive          # preserves permissions, timestamps, symlinks
  --compress         # compress during transfer
  --human-readable   # human-readable sizes in output
  --progress         # show per-file progress
  --stats            # summary stats at end
  --exclude='.DS_Store'
  --exclude='*.tmp'
  --exclude='*.log'
)

[[ "${DRY_RUN}" == true ]] && RSYNC_OPTS+=(--dry-run)

if [[ "${DRY_RUN}" == false ]]; then
  mkdir -p "${BACKUP_DEST}"
fi

info "Running rsync..."
if rsync "${RSYNC_OPTS[@]}" "${SOURCE_DIR}/" "${BACKUP_DEST}/" 2>&1 | tee "${LOG_FILE}"; then
  echo ""
  info "=== Backup complete ==="
  info "Snapshot  : ${BACKUP_DEST}"
  info "Log file  : ${LOG_FILE}"
  info "Timestamp : ${TIMESTAMP}"

  # Write backup metadata
  if [[ "${DRY_RUN}" == false ]]; then
    cat > "${BACKUP_DEST}/backup_info.txt" <<EOF
Backup completed: ${TIMESTAMP}
Source: ${SOURCE_DIR}
Destination: ${BACKUP_DEST}
Host: $(hostname)
User: $(whoami)
EOF
    info "Metadata written to backup_info.txt"
  fi
else
  die "rsync exited with an error. Check ${LOG_FILE} for details."
fi
