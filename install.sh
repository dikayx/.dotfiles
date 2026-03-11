#!/bin/zsh

#####################################################################################################
# Mac Setup & Bootstrap Script                                                                      #
#####################################################################################################

# This script bootstraps a macOS environment with:
#   - System configuration (hostname, architecture-specific setup)
#   - Dotfile symlinking
#   - Git global configuration
#   - Homebrew installation (if missing)
#   - Package installation via brew bundle
#   - Vim configuration + plugin installation
#
# The script is intentionally structured into clear sections that mirror the style of Homebrew’s
# output. Each section prints a headline followed by indented informational steps and ends with a
# success message. This makes the output predictable, minimal and easy to visually scan.
#
# ---------------------------------------------------------------------------------------------------
# Command Line Arguments
# ---------------------------------------------------------------------------------------------------
#   -hn, --hostname   <hostname>     Sets the macOS system hostname.
#   -gn, --gitname    <gitname>      Sets the global Git user.name.
#   -ge, --gitemail   <email>        Sets the global Git user.email.
#   -h,  --help                      Shows a help message and exits.
#
# Examples:
#     ./install.sh --hostname my-mac
#     ./install.sh --gitname "John Doe" --gitemail john@example.com
#
# Arguments are optional. When omitted, the script simply skips those steps.
#
# ---------------------------------------------------------------------------------------------------
# Script Architecture
# ---------------------------------------------------------------------------------------------------
# The script is divided into the following phases:
#
#   1. Pre-Installation Setup
#      - Applies system settings (hostname)
#      - Detects CPU architecture (Intel / Apple Silicon)
#      - Installs Rosetta 2 on Apple Silicon
#      - Ensures Homebrew shellenv is configured
#
#   2. Configuration Setup
#      - Creates expected directories
#      - Dynamically builds .gitconfig
#      - Reads all config files from ~/.dotfiles/configs
#      - Symlinks them into the home directory
#
#   3. Package Installation
#      - Installs Homebrew if not already present
#      - Executes package installation (brew bundle)
#
#   4. Vim Setup
#      - Installs vim-plug if missing
#      - Installs Vim plugins using the provided .vimrc
#
#   5. Post Installation
#      - Final status output
#
# ---------------------------------------------------------------------------------------------------
# Logging & Output Format
# ---------------------------------------------------------------------------------------------------
# The script uses four output helpers to mimic Homebrew’s clean style:
#
#   headline "Title"
#       Prints a section headline in the format:
#           ==> Title
#
#   info "Message"
#       Prints a simple info line describing a step inside a section.
#
#   success "Message"
#       Prints a success confirmation at the end of a section or operation.
#
#   error "Message"
#       Prints an error message with a red indicator/icon.
#
# Notes:
#   - Headlines are used only once per major section.
#   - Info lines are used for actions *within* a section.
#   - Success is used to mark the completion of a section.
#   - Error should be used for invalid arguments, failed commands, missing files, etc.
#
# ---------------------------------------------------------------------------------------------------
# Requirements
# ---------------------------------------------------------------------------------------------------
# - macOS (Intel or Apple Silicon)
# - curl
# - Internet connection for Homebrew & Vim plug-in installation
# - All scripts need to be executable (chmod +x)

#####################################################################################################
# Miscellaneous                                                                                     #
#####################################################################################################

# Color codes
RED="\e[31m"        # Errors
YELLOW="\e[33m"     # Warnings
GREEN="\e[32m"      # Success
BLUE="\e[34m"       # Information

# Formatting rules
BOLD="\e[1m"
RESET="\e[0m"

# Predefined symbols
ARROW="${BLUE}==>${RESET}"
OK="${GREEN}✔${RESET}"
ERR="${RED}✘${RESET}"

#####################################################################################################
# Helpers                                                                                           #
#####################################################################################################

headline() { echo -e "${ARROW} ${BOLD}$1${RESET}"; }
success() { echo -e "${OK} $1"; }
error() { echo -e "${ERR} $1"; }
info() { echo -e "- $1"; }

symlink() { ln -sf "$1" "$2" && success "Linked $2 -> $1" || error "Failed to link $2"; }

#####################################################################################################
# Parse command line arguments                                                                      #
#####################################################################################################

HOSTNAME=""
GITNAME=""
GITMAIL=""
SHOW_HELP=false

function show_help() {
    echo -e "${BOLD}Usage: ./install.sh [OPTIONS]${RESET}"
    echo -e "\nOptions:"
    echo -e "  -hn, --hostname <hostname>  Set the hostname of the system."
    echo -e "  -gn, --gitname <gitname>    Set the global Git user name."
    echo -e "  -ge, --gitemail <gitemail>  Set the global Git user email."
    echo -e "  -h, --help                  Show this help message and exit."
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -hn|--hostname)
            HOSTNAME=$2
            shift 2
            ;;
        -gn|--gitname)
            GITNAME=$2
            shift 2
            ;;
        -ge|--gitemail)
            GITMAIL=$2
            shift 2
            ;;
        -h|--help)
            SHOW_HELP=true
            shift
            ;;
        *)
            error "Invalid option: $1"
            show_help
            exit 1
            ;;
    esac
done

if $SHOW_HELP; then
    show_help
    exit 0
fi

#####################################################################################################
# Directories                                                                                       #
#####################################################################################################

DOTFILES_DIR="$HOME/.dotfiles"
CONFIG_DIR="$DOTFILES_DIR/configs"

#####################################################################################################
# Pre-Installation                                                                                  #
#####################################################################################################

headline "Pre-Installation Setup"

if [ -n "$HOSTNAME" ]; then
    info "Changing hostname to $HOSTNAME"
    sudo scutil --set HostName "$HOSTNAME"
fi

# Note: While almost every new Mac is Apple Silicon now, some still use Intel CPUs. To support both,
# we need to check the architecture and adjust the setup accordingly.
#
# Intel Macs don't support Rosetta nor do they need to have a special shell environment for Homebrew,
# as Homebrew installs to /usr/local on these machines, which is already in the PATH.
#
# I don't want to drop Intel support entirely yet, so this check is necessary.

CPU_ARCH=$(uname -m)

touch "${CONFIG_DIR}/.zprofile"

if [ "$CPU_ARCH" = "arm64" ]; then
    info "Apple Silicon Mac detected. Setting up Rosetta and Homebrew ..."
    sudo softwareupdate --install-rosetta --agree-to-license
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "${CONFIG_DIR}/.zprofile"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

success "Finished Pre-Installation Setup!"

#####################################################################################################
# Configuration                                                                                      #
#####################################################################################################

headline "Configuration Setup"

# Create necessary directories
info "Creating necessary directories ..."
mkdir -p "$HOME/Projekte"

# Dynamically generate .gitconfig
info "Generating Git configuration ..."
GIT_CONFIG_FILE="$CONFIG_DIR/.gitconfig"

# Clear out any existing file so we start fresh
: > "$GIT_CONFIG_FILE"

# Apply core settings
git config -f "$GIT_CONFIG_FILE" core.editor "vim"
git config -f "$GIT_CONFIG_FILE" core.autocrlf "input"
git config -f "$GIT_CONFIG_FILE" pull.ff "only"
git config -f "$GIT_CONFIG_FILE" init.defaultBranch "main"

# Apply user settings if provided
if [ -n "$GITNAME" ]; then
    git config -f "$GIT_CONFIG_FILE" user.name "$GITNAME"
fi
if [ -n "$GITMAIL" ]; then
    git config -f "$GIT_CONFIG_FILE" user.email "$GITMAIL"
fi

# Obtain a list of config files from the config directory, ignoring . and ..
files=()
for f in "$CONFIG_DIR"/.*; do
    [[ "$(basename "$f")" == "." || "$(basename "$f")" == ".." ]] && continue
    [[ -f "$f" ]] || continue # only regular files
    files+=("$(basename "$f")")
done

# Create symlinks for each config file
info "Creating symlinks ..."
for file in "${files[@]}"; do
    src="$CONFIG_DIR/$file"
    dest="$HOME/$file"
    if [ -e "$src" ]; then
        symlink "$src" "$dest"
    else
        error "$file not found in $CONFIG_DIR, skipping"
    fi
done

success "Finished Configuration Setup!"

#####################################################################################################
# Package Installation                                                                              #
#####################################################################################################

headline "Package Installation"

# Install Homebrew if missing
if ! command -v brew &> /dev/null; then
    info "Installing Homebrew ..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

info "Installing packages ..."
./brew.sh
success "Finished Package Installation!"

#####################################################################################################
# Vim Setup                                                                                         #
#####################################################################################################

headline "Vim Setup"

# Vim plugin manager installation
VIM_AUTOLOAD_DIR="$HOME/.vim/autoload"
VIM_PLUG_DIR="$VIM_AUTOLOAD_DIR/plug.vim"
mkdir -p "$VIM_AUTOLOAD_DIR"

if [ ! -f "$VIM_PLUG_DIR" ]; then
    info "Installing vim plugin manager ..."
    curl -fLo "$VIM_PLUG_DIR" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    [ -f "$VIM_PLUG_DIR" ] && success "Vim plugin manager installed!" \
                       || error "Failed to install vim plugin manager!"
else
    info "Vim plugin manager already installed, skipping."
fi

# Vim plugin silent installation
info "Installing Vim plugins ..."
vim -es -u "$CONFIG_DIR/.vimrc" +PlugInstall +qall
success "Vim Setup completed!"

#####################################################################################################
# Post Installation                                                                                 #
#####################################################################################################

headline "Installation finished!"