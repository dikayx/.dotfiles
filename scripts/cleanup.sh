#!/bin/zsh

set -euo pipefail

HOME_DIR="$HOME"
PRUNE_DAYS=10

# Cleanup targets
TARGET_DIRS=(
  "$HOME_DIR/Library/Logs"
  "$HOME_DIR/Library/Caches/Homebrew/downloads"
  "$HOME_DIR/Library/Caches/com.spotify.client/Data"
  "$HOME_DIR/Library/Application Support/discord/Cache/Cache_Data"
)

echo "Scanning for files older than $PRUNE_DAYS days..."

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

# Delete only real directories
for DIR in "${TARGET_DIRS[@]}"; do
    if [[ -d "$DIR" ]]; then
        # For testing: uncomment to preview instead of deleting
        # find "$DIR" -type f -mtime +"$PRUNE_DAYS" -print

        find "$DIR" -type f -mtime +"$PRUNE_DAYS" -delete 2>/dev/null
    fi
done

TOTAL_MB=$(awk -v bytes="$TOTAL_SIZE" 'BEGIN {printf "%.2f", bytes/1024/1024}')
echo "Cleanup complete. Total deleted: ${TOTAL_MB} MB"
