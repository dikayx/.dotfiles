#!/usr/bin/env zsh

# My DIY 'Clean your Mac'

set -euo pipefail

### Configuration ###

LIB_DIR="$HOME/Library"
PRUNE_DAYS=10

TARGET_DIRS=(
    "$LIB_DIR/Logs"
    "$LIB_DIR/Caches/Homebrew/downloads"
    "$LIB_DIR/Caches/com.spotify.client/Data"
    "$LIB_DIR/Caches/EcosiaBrowser/Default/Cache/Cache_Data"
    "$LIB_DIR/Caches/EcosiaBrowser/Default/Code Cache/js"
    "$LIB_DIR/Application Support/discord/Cache/Cache_Data"
)

### Helpers ###

to_mb() { awk -v b="$1" 'BEGIN { printf "%.2f", b / 1024 / 1024 }'; }

# Deletes files older than $PRUNE_DAYS in $1, printing the bytes freed.
# stat and rm are chained on the same find pass, so each file is
# sized before it's removed - no second traversal needed.
prune_dir() {
    find "$1" -type f -mtime +"$PRUNE_DAYS" \
        -exec stat -f%z {} + -exec rm {} + 2>/dev/null \
        | awk '{s+=$1} END {print s+0}' || true
}

### Cleanup ###

echo "Pruning files older than $PRUNE_DAYS days...\n"

total=0

for dir in "${TARGET_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        bytes=$(prune_dir "$dir")
        echo "$dir → $(to_mb "$bytes") MB deleted"
        total=$((total + bytes))
    else
        echo "Skipping missing directory: $dir"
    fi
done

echo "\nCleanup complete. Total deleted: $(to_mb "$total") MB"
