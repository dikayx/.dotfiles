#!/bin/zsh

#####################################################################################################
# Mac Setup Initialization Script                                                                   #
#####################################################################################################

# This script acts as the entry point for setting up a macOS environment via a single curl command.
# It handles the prerequisites required to pull down the dotfiles repository and hands over
# execution to the main install.sh script.
#
# ---------------------------------------------------------------------------------------------------
# Command Line Arguments
# ---------------------------------------------------------------------------------------------------
#   -hn, --hostname   <hostname>     Sets the macOS system hostname (passed to install.sh).
#   -gn, --gitname    <gitname>      Sets the global Git user.name (passed to install.sh).
#   -ge, --gitemail   <email>        Sets the global Git user.email (passed to install.sh).
#   -h,  --help                      Shows a help message and exits.
#
# Examples:
#     bash -c "$(curl -fsSL https://raw.githubusercontent.com/dikayx/.dotfiles/main/setup.sh)" \
#         -- -hn my-mac
#
# ---------------------------------------------------------------------------------------------------
# Script Architecture
# ---------------------------------------------------------------------------------------------------
# The script is divided into the following phases:
#
#   1. Prerequisites
#      - Checks for Git
#      - Triggers Xcode Command Line Tools installation if missing
#
#   2. Repository Setup
#      - Clones the dotfiles repository into ~/.dotfiles
#      - Updates it if it already exists
#
#   3. Bootstrap Execution
#      - Makes all scripts executable
#      - Hands over the parsed arguments to install.sh

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
    echo -e "${BOLD}Usage: ./setup.sh [OPTIONS]${RESET}"
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
# Prerequisites                                                                                     #
#####################################################################################################

headline "Checking Prerequisites"

if ! command -v git &> /dev/null; then
    info "Git not found. Initiating Xcode Command Line Tools installation ..."
    xcode-select --install
    error "Installation requires user interaction. Please complete the prompt and re-run this script."
    exit 1
else
    info "Git is installed."
fi

success "Prerequisites met!"

#####################################################################################################
# Repository Setup                                                                                  #
#####################################################################################################

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

success "Repository setup complete!"

#####################################################################################################
# Bootstrap Execution                                                                               #
#####################################################################################################

headline "Bootstrap Execution"

info "Making scripts in .dotfiles executable ..."
chmod +x "$DOTFILES_DIR"/*.sh

info "Handing over to install.sh ..."

# Execute install.sh with the provided arguments
"$DOTFILES_DIR"/install.sh -hn "$HOSTNAME" -gn "$GITNAME" -ge "$GITMAIL"