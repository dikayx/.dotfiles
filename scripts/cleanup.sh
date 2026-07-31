#!/bin/zsh

#####################################################################################################
# My cleanup script to remove old cache and log files                                                #
#####################################################################################################

set -euo pipefail

#####################################################################################################
# Configuration                                                                                      #
#####################################################################################################

HOME_DIR="$HOME"
USR_LIB_DIR="$HOME_DIR/Library"
PRUNE_DAYS=10

# Cleanup targets
TARGET_DIRS=(
  "$USR_LIB_DIR/Logs"
  "$USR_LIB_DIR/Caches/Homebrew/downloads"
  "$USR_LIB_DIR/Caches/com.spotify.client/Data"
  "$USR_LIB_DIR/Caches/BraveSoftware/Brave-Browser/Default/Cache/Cache_Data"
  "$USR_LIB_DIR/Application Support/discord/Cache/Cache_Data"
)

echo "Scanning for files older than $PRUNE_DAYS days..."

#####################################################################################################
# Calculate total size to be deleted                                                                #
#####################################################################################################

TOTAL_SIZE=0

# Function to calculate size in bytes
calculate_size() {
    local dir="$1"
    find "$dir" -type f -mtime +"$PRUNE_DAYS" -exec stat -f%z {} + 2>/dev/null \
        | awk '{s+=$1} END {print s+0}'
}

for DIR in "${TARGET_DIRS[@]}"; do
    if [[ -d "$DIR" ]]; then
        SIZE_BYTES=$(calculate_size "$DIR")
        SIZE_MB=$(awk -v bytes="$SIZE_BYTES" 'BEGIN {printf "%.2f", bytes/1024/1024}')

        echo "$DIR → ${SIZE_MB} MB will be deleted"

        TOTAL_SIZE=$((TOTAL_SIZE + SIZE_BYTES))
    else
        echo "Skipping missing directory: $DIR"
    fi
done

echo
echo "Deleting files older than $PRUNE_DAYS days..."

#####################################################################################################
# Delete old files                                                                                   #
#####################################################################################################

for DIR in "${TARGET_DIRS[@]}"; do
    if [[ -d "$DIR" ]]; then
        find "$DIR" -type f -mtime +"$PRUNE_DAYS" -delete 2>/dev/null
    fi
done

TOTAL_MB=$(awk -v bytes="$TOTAL_SIZE" 'BEGIN {printf "%.2f", bytes/1024/1024}')
echo "Cleanup complete. Total deleted: ${TOTAL_MB} MB"
