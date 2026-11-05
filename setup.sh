#!/bin/bash

# Bootstrap for macOS and Linux Mint: installs git, clones the repo, runs install.sh.
# Windows: use setup.ps1 instead.

set -euo pipefail

### Colors & helpers ###

GREEN=$'\033[32m'; RED=$'\033[31m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

headline() { printf '%s* %s%s\n' "${BOLD}${GREEN}" "$1" "$RESET"; }
info()     { printf '  %s\n' "$1"; }
error()    { printf '%s%s%s\n' "$RED" "$1" "$RESET" >&2; }

has_git() { git --version &> /dev/null; }

headline "Checking Prerequisites"

if has_git; then
    info "Git is already installed."
else
    case "$(uname -s)" in
        Darwin)
            info "Git not found. Initiating Xcode Command Line Tools installation ..."
            xcode-select --install
            info "Waiting for installation to complete (this may take a few minutes) ..."
            until has_git; do sleep 5; done
            info "Xcode Command Line Tools installed."
            ;;
        Linux)
            if ! command -v apt-get &> /dev/null; then
                error "apt-get not found. This setup supports Linux Mint (apt based systems)."
                exit 1
            fi
            info "Git not found. Installing git via apt ..."
            sudo apt-get update
            sudo apt-get install -y git
            ;;
        *)
            error "Unsupported OS '$(uname -s)'. On Windows use setup.ps1."
            exit 1
            ;;
    esac
fi

headline "Repository Setup"

DOTFILES_DIR="$HOME/.dotfiles"

if [ -d "$DOTFILES_DIR" ]; then
    info "Dotfiles directory already exists at $DOTFILES_DIR."
    info "Pulling latest changes ..."
    git -C "$DOTFILES_DIR" pull
else
    info "Cloning dotfiles repository to $DOTFILES_DIR ..."
    git clone https://github.com/dikayx/.dotfiles.git "$DOTFILES_DIR"
fi

headline "Bootstrap Execution"

info "Making scripts in .dotfiles executable ..."
chmod +x "$DOTFILES_DIR"/*.sh "$DOTFILES_DIR"/scripts/* 2>/dev/null || true

info "Handing over to install.sh ..."

exec "$DOTFILES_DIR/install.sh" "$@"
