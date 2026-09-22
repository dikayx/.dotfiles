#!/usr/bin/env zsh

set -euo pipefail

### Colors & helpers ###

GREEN="\e[32m"
RED="\e[31m"
BOLD="\e[1m"
RESET="\e[0m"

headline() { echo -e "${BOLD}${GREEN}* $1${RESET}"; }
info() { echo -e "  $1"; }
error() { echo -e "${RED}$1${RESET}"; }

symlink() { ln -sf "$1" "$2" && info "Linked $2 -> $1" || error "Failed to link $2"; }

### Parse command line arguments ###

NEW_HOSTNAME=""
GITNAME=""
GITMAIL=""

show_help() {
    echo -e "${BOLD}Usage: ./install.sh [OPTIONS]${RESET}"
    echo -e "\nOptions:"
    echo -e "  -hn, --hostname <hostname>  Set the hostname of the system."
    echo -e "  -gn, --gitname <gitname>    Set the global Git user name."
    echo -e "  -ge, --gitemail <gitemail>  Set the global Git user email."
    echo -e "  -h,  --help                 Show this help message and exit."
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -hn|--hostname) NEW_HOSTNAME="$2"; shift 2 ;;
        -gn|--gitname)  GITNAME="$2";      shift 2 ;;
        -ge|--gitemail) GITMAIL="$2";      shift 2 ;;
        -h|--help)      show_help; exit 0 ;;
        *) error "Invalid option: $1"; show_help; exit 1 ;;
    esac
done

### Installation ###

headline "Pre-Installation Setup"

if [ -n "$NEW_HOSTNAME" ]; then
    info "Changing hostname to $NEW_HOSTNAME"
    # Setting all 3 hostname types for network consistency
    for key in ComputerName HostName LocalHostName; do
        sudo scutil --set "$key" "$NEW_HOSTNAME"
    done
fi

CPU_ARCH=$(uname -m)

if [ "$CPU_ARCH" = "arm64" ]; then
    if pgrep -q oahd; then
        info "Rosetta 2 already installed, skipping."
    else
        info "Apple Silicon Mac detected. Installing Rosetta 2 ..."
        sudo softwareupdate --install-rosetta --agree-to-license
    fi
fi

headline "Configuration Setup"

DOTFILES_DIR="$HOME/.dotfiles"
CONFIG_DIR="$DOTFILES_DIR/configs"
mkdir -p "$HOME/Projekte"

# Walk through the configs/ directory and create symlinks for each dotfile
while IFS= read -r -d '' src; do
    rel="${src#$CONFIG_DIR/}"
    dest="$HOME/$rel"
    symlink "$src" "$dest"
done < <(find "$CONFIG_DIR" -maxdepth 1 -name ".*" -type f -print0)

# Apply git settings if provided (short-circuit)
[ -n "$GITNAME" ] && git config --global user.name "$GITNAME"
[ -n "$GITMAIL" ] && git config --global user.email "$GITMAIL"

# Symlink/copy settings from settings/ to their respective locations
mkdir -p "${HOME}/.config/ghostty"
symlink "$CONFIG_DIR/settings/ghostty-config" "${HOME}/.config/ghostty/config"

headline "Package Installation"

if ! command -v brew &> /dev/null; then
    info "Installing Homebrew ..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

info "Updating Homebrew ..."
brew update

info "Installing packages from Brewfile ..."
HOMEBREW_NO_ASK=1 HOMEBREW_BUNDLE_NO_UPGRADE=1 brew bundle install --file="$DOTFILES_DIR/Brewfile"

info "Cleaning up ..."
brew cleanup

headline "Vim Setup"

VIM_PLUG_FILE="$HOME/.vim/autoload/plug.vim"

if [ ! -f "$VIM_PLUG_FILE" ]; then
    info "Installing vim plugin manager ..."
    curl -fLo "$VIM_PLUG_FILE" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
        && info "Vim plugin manager installed." \
        || error "Failed to install vim plugin manager!"
else
    info "Vim plugin manager already installed, skipping."
fi

info "Installing Vim plugins ..."
vim -es -u "$CONFIG_DIR/.vimrc" +PlugInstall +qall

headline "Setting Terminal Profile"
 
TERMINAL_PROFILE_FILE="$DOTFILES_DIR/Predawn.terminal"
TERMINAL_PROFILE_NAME=$(plutil -extract name raw -o - "$TERMINAL_PROFILE_FILE" 2>/dev/null)
 
if [ -n "$TERMINAL_PROFILE_NAME" ]; then
    info "Importing Terminal profile ${TERMINAL_PROFILE_NAME} ..."
    open "$TERMINAL_PROFILE_FILE"
    sleep 1
    defaults write com.apple.Terminal "Default Window Settings" -string "$TERMINAL_PROFILE_NAME"
    defaults write com.apple.Terminal "Startup Window Settings" -string "$TERMINAL_PROFILE_NAME"
else
    error "Could not read profile name from $TERMINAL_PROFILE_FILE"
fi

headline "Installation finished!"
