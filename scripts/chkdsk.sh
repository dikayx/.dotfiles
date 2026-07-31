#!/bin/zsh

#####################################################################################################
# Check disk health and wear level on macOS using smartmontools (smartctl)                          #
#####################################################################################################

# chkdsk.sh — Print a one-line SSD wear/health summary on macOS using
#                 smartmontools (smartctl).
#
# Example output:
#   SSD Healthy (98% remaining)
#
# Usage:
#   ./chkdsk.sh [device]
#
#   device   Optional BSD disk identifier, e.g. disk0, disk1, /dev/disk0.
#            Defaults to disk0 (usually the internal boot drive on Macs).
#
# Notes / limitations:
#   - Requires smartmontools:            brew install smartmontools
#   - The script first tries reading SMART data as the current user (this
#     often just works on macOS, e.g. for the console-logged-in user).
#     Only if that fails with a permissions error does it transparently
#     re-invoke itself with sudo.
#   - On Apple Silicon (and some T2) Macs, Apple's proprietary NVMe
#     controller may not expose standard SMART attributes to smartctl.
#     This is a macOS/hardware limitation, not a bug in this script.
#   - For SATA SSDs, "remaining life" is read from whichever vendor
#     attribute is present (SSD_Life_Left, Percent_Lifetime_Remain,
#     Media_Wearout_Indicator, Wear_Leveling_Count). Vendors are not
#     fully consistent in how they populate these, so treat the number
#     as a good approximation rather than an exact figure.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
DEFAULT_DEVICE="disk0"

#####################################################################################################
# Helpers                                                                                           #
#####################################################################################################
die() {
    echo "Error: $*" >&2
    exit 1
}

warn() {
    echo "Warning: $*" >&2
}

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [device]

Prints the wear/health status of an SSD, e.g.:
    SSD Healthy (98% remaining)

Arguments:
  device    Optional BSD disk identifier (e.g. disk0, disk1, /dev/disk0).
            Defaults to '${DEFAULT_DEVICE}'.

Requirements:
  - smartmontools installed (brew install smartmontools)
  - root privileges, only if unprivileged access is denied (the script
    tries without sudo first and escalates automatically if needed)

Exit codes:
  0  Healthy or Warning tier (see output)
  1  Critical wear level
  2  SMART overall health check reports FAILED
  3  Health/wear data could not be determined
EOF
}

#####################################################################################################
# Check for flags                                                                                    #
#####################################################################################################

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

#####################################################################################################
# Prerequisites                                                                                     #
#####################################################################################################

if [[ "$(uname -s)" != "Darwin" ]]; then
    die "This script is intended for macOS only."
fi

if ! command -v smartctl >/dev/null 2>&1; then
    die "smartctl not found. Install smartmontools first, e.g.:
       brew install smartmontools"
fi
SMARTCTL_BIN="$(command -v smartctl)"

#####################################################################################################
# Check the device                                                                                  #
#####################################################################################################
RAW_DEVICE="${1:-$DEFAULT_DEVICE}"
RAW_DEVICE="${RAW_DEVICE#/dev/}"      # normalize away any /dev/ prefix
DEVICE="/dev/${RAW_DEVICE}"

if [[ ! -e "$DEVICE" ]]; then
    die "Device '${DEVICE}' does not exist. Available disks:
$(diskutil list 2>/dev/null | grep -E '^/dev/disk' || echo '  (unable to list disks)')"
fi

#####################################################################################################
# Check if the drive is an SSD and read SMART data                                                  #
#####################################################################################################

# Depending on drive type and macOS version, smartctl either reads data macOS already publishes for 
# any user to see, or has to open the raw device / issue a passthrough command, which needs root. 
# Rather than assume, we just try without sudo and only escalate if that attempt actually fails on 
# permissions.

INFO_STATUS=0
INFO_OUTPUT="$("$SMARTCTL_BIN" -i "$DEVICE" 2>&1)" || INFO_STATUS=$?

if [[ $INFO_STATUS -ne 0 ]] && [[ "${EUID}" -ne 0 ]] \
   && grep -qiE "permission denied|operation not permitted|must be (run as )?root|unable to open" <<<"$INFO_OUTPUT"; then
    if command -v sudo >/dev/null 2>&1; then
        echo "Insufficient permissions to read ${DEVICE} as the current user; re-running with sudo..." >&2
        exec sudo bash "$0" "$RAW_DEVICE"
    else
        die "Reading ${DEVICE} requires root, and sudo is not available:
${INFO_OUTPUT}"
    fi
fi

if [[ $INFO_STATUS -ne 0 ]]; then
    die "smartctl could not read device info for ${DEVICE}. Raw output:
${INFO_OUTPUT}"
fi

if grep -qi "Unable to detect device type" <<<"$INFO_OUTPUT"; then
    die "smartctl could not detect a supported device type for ${DEVICE}."
fi

if grep -qi "SMART support is:.*Unavailable" <<<"$INFO_OUTPUT"; then
    die "SMART is not supported on ${DEVICE}."
fi

IS_NVME=false
grep -qi "NVMe" <<<"$INFO_OUTPUT" && IS_NVME=true

if [[ "$IS_NVME" == false ]]; then
    ROTATION_LINE="$(grep -i "Rotation Rate" <<<"$INFO_OUTPUT" || true)"
    if [[ -n "$ROTATION_LINE" ]] && ! grep -qi "Solid State Device" <<<"$ROTATION_LINE"; then
        die "${DEVICE} does not appear to be an SSD (a rotation rate was reported):
${ROTATION_LINE}
This script only supports SSDs."
    fi
fi

#####################################################################################################
# Pull full SMART data                                                                              #
#####################################################################################################

# "-a" can in principle need broader access than "-i" did, even if the earlier probe succeeded 
# unprivileged — so we apply the same try-then-escalate logic here too, just in case.

set +o errexit  # smartctl exits non-zero on various SMART warning bits, even when data was read 
                # successfully — inspect output instead of relying on the exit code.

FULL_OUTPUT="$("$SMARTCTL_BIN" -a "$DEVICE" 2>&1)"
FULL_STATUS=$?
set -o errexit

if [[ $FULL_STATUS -ne 0 ]] && [[ "${EUID}" -ne 0 ]] \
   && grep -qiE "permission denied|operation not permitted|must be (run as )?root|unable to open" <<<"$FULL_OUTPUT"; then
    if command -v sudo >/dev/null 2>&1; then
        echo "Insufficient permissions to read full SMART data for ${DEVICE}; re-running with sudo..." >&2
        exec sudo bash "$0" "$RAW_DEVICE"
    else
        die "Reading full SMART data for ${DEVICE} requires root, and sudo is not available:
${FULL_OUTPUT}"
    fi
fi

if [[ -z "$FULL_OUTPUT" ]]; then
    die "smartctl returned no data for ${DEVICE}."
fi

#####################################################################################################
# Overall health assessment                                                                         #
#####################################################################################################

HEALTH_LINE="$(grep -i "overall-health self-assessment" <<<"$FULL_OUTPUT" || true)"
HEALTH_STATUS="UNKNOWN"
if [[ -n "$HEALTH_LINE" ]]; then
    if grep -qi "PASSED" <<<"$HEALTH_LINE"; then
        HEALTH_STATUS="PASSED"
    elif grep -qi "FAILED" <<<"$HEALTH_LINE"; then
        HEALTH_STATUS="FAILED"
    fi
fi

#####################################################################################################
# Extract remaining-life percentage                                                                 #
#####################################################################################################

# NVMe : "Percentage Used:" (0-100) -> remaining = 100 - used
# SATA : first matching vendor attribute's VALUE column

REMAINING_PERCENT=""

if [[ "$IS_NVME" == true ]]; then
    PCT_USED_LINE="$(grep -i "Percentage Used" <<<"$FULL_OUTPUT" || true)"
    if [[ -n "$PCT_USED_LINE" ]]; then
        PCT_USED="$(grep -oE '[0-9]+%' <<<"$PCT_USED_LINE" | head -1 | tr -d '%')"
        [[ -n "$PCT_USED" ]] && REMAINING_PERCENT=$((100 - PCT_USED))
    fi
else
    for ATTR_NAME in "SSD_Life_Left" "Percent_Lifetime_Remain" "Media_Wearout_Indicator" "Wear_Leveling_Count"; do
        ATTR_LINE="$(grep -i "$ATTR_NAME" <<<"$FULL_OUTPUT" || true)"
        if [[ -n "$ATTR_LINE" ]]; then
            # Attribute table columns: ID# NAME FLAG VALUE WORST THRESH ...
            VALUE_COL="$(awk '{print $4}' <<<"$ATTR_LINE")"
            if [[ "$VALUE_COL" =~ ^[0-9]+$ ]]; then
                REMAINING_PERCENT="$VALUE_COL"
                break
            fi
        fi
    done
fi

#####################################################################################################
# Print summary and exit with appropriate code                                                      #
#####################################################################################################

if [[ "$HEALTH_STATUS" == "FAILED" ]]; then
    if [[ -n "$REMAINING_PERCENT" ]]; then
        echo "SSD FAILED (${REMAINING_PERCENT}% remaining) — back up your data and replace the drive immediately"
    else
        echo "SSD FAILED — back up your data and replace the drive immediately"
    fi
    exit 2
fi

[[ "$HEALTH_STATUS" == "UNKNOWN" ]] && warn "Could not determine overall SMART health status from smartctl output."

if [[ -n "$REMAINING_PERCENT" ]]; then
    if (( REMAINING_PERCENT <= 10 )); then
        echo "SSD Critical (${REMAINING_PERCENT}% remaining) — consider replacing the drive soon"
        exit 1
    elif (( REMAINING_PERCENT <= 30 )); then
        echo "SSD Warning (${REMAINING_PERCENT}% remaining)"
        exit 0
    else
        echo "SSD Healthy (${REMAINING_PERCENT}% remaining)"
        exit 0
    fi
fi

if [[ "$HEALTH_STATUS" == "PASSED" ]]; then
    echo "SSD Healthy (remaining life percentage not reported by this drive)"
    exit 0
fi

echo "SSD status unknown — could not read wear or health data for ${DEVICE}"
exit 3
