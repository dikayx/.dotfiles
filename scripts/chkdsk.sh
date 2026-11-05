#!/bin/bash

# Check SSD wear/health on macOS and Linux (requires smartmontools, assumes an NVMe SSD)

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
case "$(uname -s)" in
    Darwin) OS="macos"; DEFAULT_DEVICE="disk0"; INSTALL_HINT="brew install smartmontools" ;;
    Linux)  OS="linux"; DEFAULT_DEVICE="nvme0"; INSTALL_HINT="sudo apt install smartmontools" ;;
    *)      echo "Error: unsupported OS '$(uname -s)'." >&2; exit 1 ;;
esac

### Helpers ###

die() {
    echo "Error: $*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [device]

Prints the wear/health status of an SSD, e.g.:
    SSD Healthy (98% remaining)

Arguments:
  device    Optional disk identifier (macOS: disk0, /dev/disk0; Linux: nvme0, /dev/nvme0).
            Defaults to '${DEFAULT_DEVICE}'.

Requirements:
  - smartmontools installed (brew / apt install smartmontools)
  - root privileges, only if unprivileged access is denied (the script
    tries without sudo first and escalates automatically if needed)

Exit codes:
  0  Healthy or Warning tier (see output)
  1  Critical wear level
  2  SMART critical warning flagged
  3  Wear data could not be determined
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

### Prerequisites ###

list_disks() {
    if [[ "$OS" == "macos" ]]; then
        diskutil list 2>/dev/null | grep -E '^/dev/disk' || echo '  (unable to list disks)'
    else
        lsblk -d -o NAME,SIZE,MODEL 2>/dev/null || echo '  (unable to list disks)'
    fi
}

command -v smartctl >/dev/null 2>&1 \
    || die "smartctl not found. Install smartmontools first, e.g.: ${INSTALL_HINT}"

RAW_DEVICE="${1:-$DEFAULT_DEVICE}"
RAW_DEVICE="${RAW_DEVICE#/dev/}"      # normalize away any /dev/ prefix
DEVICE="/dev/${RAW_DEVICE}"

[[ -e "$DEVICE" ]] || die "Device '${DEVICE}' does not exist. Available disks:
$(list_disks)"

### Read SMART data ###

set +o errexit
OUTPUT="$(smartctl -A "$DEVICE" 2>&1)"
STATUS=$?
set -o errexit

if [[ $STATUS -ne 0 ]] && [[ "${EUID}" -ne 0 ]] \
   && grep -qiE "permission denied|operation not permitted|must be (run as )?root|unable to open" <<<"$OUTPUT"; then
    command -v sudo >/dev/null 2>&1 \
        || die "Reading ${DEVICE} requires root, and sudo is not available:
${OUTPUT}"
    echo "Insufficient permissions to read ${DEVICE}; re-running with sudo..." >&2
    exec sudo bash "$0" "$RAW_DEVICE"
fi

### Health assessment ###

CRITICAL_WARNING="$(grep -i "Critical Warning" <<<"$OUTPUT" | awk '{print $NF}' || true)"
USED_PERCENT="$(grep -i "Percentage Used" <<<"$OUTPUT" | grep -oE '[0-9]+' | head -1 || true)"

[[ -n "$USED_PERCENT" ]] || die "Could not read wear data for ${DEVICE}. Raw output:
${OUTPUT}"

REMAINING=$((100 - USED_PERCENT))

if [[ -n "$CRITICAL_WARNING" && "$CRITICAL_WARNING" != "0x00" ]]; then
    echo "SSD FAILED (${REMAINING}% remaining, critical warning ${CRITICAL_WARNING}) — back up your data and replace the drive immediately"
    exit 2
elif (( REMAINING <= 10 )); then
    echo "SSD Critical (${REMAINING}% remaining) — consider replacing the drive soon"
    exit 1
elif (( REMAINING <= 30 )); then
    echo "SSD Warning (${REMAINING}% remaining)"
else
    echo "SSD Healthy (${REMAINING}% remaining)"
fi
