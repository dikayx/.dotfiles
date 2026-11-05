#!/bin/bash

# Unified installer for macOS and Linux Mint (Windows: install.ps1).
# Shared steps live in lib/common.sh, OS specific ones in platforms/<os>/platform.sh.

set -euo pipefail

DOTFILES_DIR="$HOME/.dotfiles"
# shellcheck source=lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

detect_os
parse_args "$@"
# shellcheck disable=SC1090
. "$DOTFILES_DIR/platforms/$DOTFILES_OS/platform.sh"

headline "Pre-Installation Setup ($DOTFILES_OS)"

if [ -n "$NEW_HOSTNAME" ]; then
    platform_set_hostname "$NEW_HOSTNAME"
fi
platform_prepare

headline "Configuration Setup"

mkdir -p "$HOME/Projekte"
link_configs
set_git_identity

headline "Package Installation"
platform_install_packages

headline "Vim Setup"
setup_vim

headline "Setting Terminal Profile"
platform_setup_terminal

platform_finish

headline "Installation finished!"
