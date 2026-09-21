#!/usr/bin/env zsh

# Exit on error
set -euo pipefail

### Colors & helpers ###

GREEN="\e[32m"
RED="\e[31m"
BOLD="\e[1m"
RESET="\e[0m"

headline() { echo -e "${BOLD}${GREEN}* $1${RESET}"; }
info() { echo -e "  $1"; }
error() { echo -e "${RED}$1${RESET}"; }

has_git() { git --version &> /dev/null; }

headline "Checking Prerequisites"

if ! has_git; then
    info "Git not found. Initiating Xcode Command Line Tools installation ..."
    xcode-select --install
    info "Waiting for installation to complete (this may take a few minutes) ..."
    until has_git; do
        sleep 5
    done
    info "Xcode Command Line Tools installed."
else
    info "Git is already installed."
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
chmod +x "$DOTFILES_DIR"/*.sh "$DOTFILES_DIR"/scripts/*.sh 2>/dev/null || true

info "Handing over to install.sh ..."

exec "$DOTFILES_DIR/install.sh" "$@"
