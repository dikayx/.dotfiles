#!/bin/bash

# My DIY 'Clean your Mac / Linux box'

set -euo pipefail

### Configuration ###

PRUNE_DAYS=10

case "$(uname -s)" in
    Darwin)
        LIB_DIR="$HOME/Library"
        STAT_SIZE=(stat -f%z)
        TARGET_DIRS=(
            "$LIB_DIR/Logs"
            "$LIB_DIR/Caches/Homebrew/downloads"
            "$LIB_DIR/Caches/com.spotify.client/Browser/Cache/Cache_Data"
            "$LIB_DIR/Caches/EcosiaBrowser/Default/Cache/Cache_Data"
            "$LIB_DIR/Caches/EcosiaBrowser/Default/Code Cache/js"
            "$LIB_DIR/Application Support/discord/Cache/Cache_Data"
        )
        ;;
    Linux)
        STAT_SIZE=(stat -c%s)
        TARGET_DIRS=(
            "$HOME/.cache/thumbnails"
            "$HOME/.cache/spotify"
            "$HOME/.config/discord/Cache/Cache_Data"
            # Flatpak builds of Spotify / Discord
            "$HOME/.var/app/com.spotify.Client/cache"
            "$HOME/.var/app/com.discordapp.Discord/config/discord/Cache/Cache_Data"
        )
        ;;
    *)
        echo "Unsupported OS: $(uname -s)" >&2
        exit 1
        ;;
esac

### Helpers ###

to_mb() { awk -v b="$1" 'BEGIN { printf "%.2f", b / 1024 / 1024 }'; }

# Deletes files older than $PRUNE_DAYS in $1, printing the bytes freed.
# stat and rm are chained on the same find pass, so each file is
# sized before it's removed - no second traversal needed.
prune_dir() {
    find "$1" -type f -mtime +"$PRUNE_DAYS" \
    -exec "${STAT_SIZE[@]}" {} \; -exec rm -f {} \; 2>/dev/null \
    | awk '{s+=$1} END {print s+0}'
}

### Cleanup ###

printf 'Pruning files older than %s days...\n\n' "$PRUNE_DAYS"

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

printf '\nCleanup complete. Total deleted: %s MB\n' "$(to_mb "$total")"
