#!/bin/zsh

#####################################################################################################
# chkbrew — find Homebrew formulae that are not required by any other installed formulae.            #
#####################################################################################################

# Finds installed Homebrew formulae that are not required by any other
# installed formula ("leaves") and offers to uninstall them.
#
# Only formulae are analyzed (casks are almost never dependencies of
# anything, so including them wouldn't add useful signal here).
#
# Requirements: Homebrew, jq  (install jq with: brew install jq)
#
# Usage:
#   zsh chkbrew.sh              interactive report + optional uninstall
#   zsh chkbrew.sh --no-prompt  print the report only, never prompt
#   zsh chkbrew.sh -h           show help

#####################################################################################################
# Helpers                                                                                           #
#####################################################################################################

set -eo pipefail

NO_PROMPT=0

usage() {
  cat <<'EOF'
Usage: chkbrew.sh [options]

Options:
  -n, --no-prompt   Print the report only; never offer to uninstall anything.
  -h, --help        Show this help.

What it does:
  1. Reads all installed Homebrew formulae.
  2. Builds a map of which installed formulae depend on which.
  3. Lists formulae with ZERO installed dependents ("leaves") - candidates
     you can review and optionally uninstall right from this script.
EOF
}

for arg in "$@"; do
  case "$arg" in
    -n|--no-prompt) NO_PROMPT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage; exit 1 ;;
  esac
done

# Colors (only when attached to a terminal)
if [ -t 1 ]; then
  BOLD=$(tput bold); RESET=$(tput sgr0)
  YELLOW=$(tput setaf 3); GREEN=$(tput setaf 2); CYAN=$(tput setaf 6)
else
  BOLD=""; RESET=""; YELLOW=""; GREEN=""; CYAN=""
fi

#####################################################################################################
# Sanity checks                                                                                     #
#####################################################################################################

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew was not found in PATH. Install it from https://brew.sh first." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: this script needs 'jq'. Install it with: brew install jq" >&2
  exit 1
fi

echo "${CYAN}Gathering installed Homebrew formula info (this can take a few seconds)...${RESET}"

if ! INFO_JSON="$(brew info --json=v2 --installed 2>/dev/null)"; then
  echo "Error: 'brew info --json=v2 --installed' failed. Is your Homebrew up to date?" >&2
  exit 1
fi

FORMULA_COUNT="$(printf '%s' "$INFO_JSON" | jq '.formulae | length')"

if [ "$FORMULA_COUNT" -eq 0 ]; then
  echo "No installed formulae found."
  exit 0
fi

#####################################################################################################
# Build the dependency map                                                                          #
#####################################################################################################

# Output TSV columns (pre-sorted by name so the loop below needs no extra sort step):
# name | installed_on_request(true/false) | dependent_count

TSV_DATA="$(printf '%s' "$INFO_JSON" | jq -r '
  .formulae as $formulae
  | (reduce $formulae[] as $f
      ({};
        reduce ($f.dependencies // [])[] as $d
          (.; .[$d] = ((.[$d] // []) + [$f.name]))
      )
    ) as $revmap
  | $formulae[]
  | ($revmap[.name] // []) as $users
  | [
      .name,
      ((.installed[0].installed_on_request // false) | tostring),
      ($users | length | tostring)
    ]
  | @tsv
' | sort -f)"

LEAVES=()   # "name|requested"
HAS_ORPHAN=0

while IFS=$'\t' read -r name requested count; do
  [ -z "$name" ] && continue
  if [ "$count" -eq 0 ]; then
    LEAVES+=("${name}|${requested}")
    [ "$requested" = "false" ] && HAS_ORPHAN=1
  fi
done <<< "$TSV_DATA"

#####################################################################################################
# Report                                                                                            #
#####################################################################################################

echo
echo "${BOLD}Checked ${FORMULA_COUNT} installed formulae.${RESET}"
echo

echo "${BOLD}${GREEN}=== Not required by any other installed formula (${#LEAVES[@]}) ===${RESET}"
if [ ${#LEAVES[@]} -eq 0 ]; then
  echo "  (none)"
else
  i=0
  for entry in "${LEAVES[@]}"; do
    i=$((i + 1))
    name="${entry%%|*}"
    requested="${entry##*|}"
    if [ "$requested" = "true" ]; then
      tag="${CYAN}explicitly installed${RESET}"
    else
      tag="${YELLOW}installed as a dependency - possibly orphaned${RESET}"
    fi
    printf "  %2d) %-30s [%s]\n" "$i" "$name" "$tag"
  done
fi

if [ "$HAS_ORPHAN" -eq 1 ]; then
  echo
  echo "${CYAN}Tip:${RESET} entries marked 'installed as a dependency - possibly orphaned' may also"
  echo "show up in: brew autoremove --dry-run"
fi

#####################################################################################################
# Optional interactive uninstall                                                                    #
#####################################################################################################

if [ "$NO_PROMPT" -eq 1 ] || [ ! -t 0 ] || [ ${#LEAVES[@]} -eq 0 ]; then
  exit 0
fi

echo
printf '%s' "Uninstall any of the above? Enter numbers (e.g. 1 3 5), or press Enter to skip: "
read -r selection
if [ -z "$selection" ]; then
  echo "No changes made."
  exit 0
fi

TO_REMOVE=()
for num in ${=selection}; do
  case "$num" in
    ''|*[!0-9]*)
      echo "Skipping invalid entry: $num" >&2
      continue
      ;;
  esac
  if [ "$num" -ge 1 ] && [ "$num" -le "${#LEAVES[@]}" ]; then
    entry="${LEAVES[$num]}"
    TO_REMOVE+=("${entry%%|*}")
  else
    echo "Skipping out-of-range entry: $num" >&2
  fi
done

if [ ${#TO_REMOVE[@]} -eq 0 ]; then
  echo "Nothing valid selected. No changes made."
  exit 0
fi

echo
echo "About to uninstall: ${TO_REMOVE[*]}"
printf '%s' "Confirm? [y/N] "
read -r confirm
case "$confirm" in
  y|Y|yes|YES)
    brew uninstall "${TO_REMOVE[@]}"
    ;;
  *)
    echo "Cancelled. No changes made."
    ;;
esac
