#!/bin/zsh

#####################################################################################################
# This script sets up my Mac with all my favorite apps and tools and creates symlinks.              #
#####################################################################################################

#####################################################################################################
# Miscellanous                                                                                      #
#####################################################################################################

# Color codes for output
RED="\e[31m"        # Errors
YELLOW="\e[33m"     # Warnings
GREEN="\e[32m"      # Success
ENDCOLOR="\e[0m"    # Reset

#####################################################################################################
# Helpers                                                                                           #
#####################################################################################################

cecho() { echo -e "${2}$1${ENDCOLOR}"; }
symlink() { ln -sf "$1" "$2"; cecho "Linked $2 -> $1" "$YELLOW"; }

#####################################################################################################
# Parse command line arguments                                                                      #
#####################################################################################################

HOSTNAME=""
GITNAME=""
GITMAIL=""
SHOW_HELP=false

function show_help() {
    echo -e "${YELLOW}Usage: ./install.sh [OPTIONS]${ENDCOLOR}"
    echo -e "\nOptions:"
    echo -e "  -hn, --hostname <hostname>  Set the hostname of the system."
    echo -e "  -gn, --gitname <gitname>    Set the Git user name."
    echo -e "  -ge, --gitemail <gitemail>  Set the Git user email."
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
            echo -e "${RED}Invalid option: $1${ENDCOLOR}" >&2
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
# Preinstallation                                                                                   #
#####################################################################################################

if [ -n "$HOSTNAME" ]; then
    cecho "Changing hostname to $HOSTNAME" "$YELLOW"
    sudo scutil --set HostName "$HOSTNAME"
fi

#####################################################################################################
# Directories                                                                                       #
#####################################################################################################

HOMEDIR="$HOME"
DOTFILESDIR="$HOMEDIR/.dotfiles"
CONFIGDIR="$DOTFILESDIR/configs"

#####################################################################################################
# Architecture specific setup                                                                        #
#####################################################################################################

# Get system architecture
CPU_ARCH=$(uname -m)

# Create a local .zprofile for custom env variables
touch "${CONFIGDIR}/.zprofile"

# Additional Homebrew settings for ARM Macs
if [ "$CPU_ARCH" = "arm64" ]; then
    cecho "Apple Silicon Mac detected. Setting up Rosetta and Homebrew..." "$YELLOW"
    sudo softwareupdate --install-rosetta --agree-to-license
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "${CONFIGDIR}/.zprofile"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

cecho "✅ Finished preliminary setup!" "$GREEN"

#####################################################################################################
# Configuration                                                                                      #
#####################################################################################################

# Create necessary directories
cecho "🗂 Creating necessary directories..." "$YELLOW"
mkdir -p "$HOMEDIR/Projekte"

# Obtain list of config files from CONFIGDIR, ignoring . and ..
files=()
for f in "$CONFIGDIR"/.*; do
    [[ "$(basename "$f")" == "." || "$(basename "$f")" == ".." ]] && continue
    [[ -f "$f" ]] || continue  # only regular files
    files+=("$(basename "$f")")
done

# Create symlinks for each config file
for file in "${files[@]}"; do
    src="$CONFIGDIR/$file"
    dest="$HOMEDIR/$file"
    if [ -e "$src" ]; then
        symlink "$src" "$dest"
    else
        cecho "⚠️ $file not found in $CONFIGDIR, skipping" "$RED"
    fi
done

# Setup git if gitname and gitemail are given
if [ -n "$GITNAME" ] && [ -n "$GITMAIL" ]; then
    cecho "🔧 Setting up git..." "$YELLOW"
    git config --global user.name "$GITNAME"
    git config --global user.email "$GITMAIL"
fi
    
cecho "✅ Finished configuration!" "$GREEN"

#####################################################################################################
# Package installation                                                                              #
#####################################################################################################

# Install Homebrew if missing
if ! command -v brew &> /dev/null; then
    cecho "🍺 Installing Homebrew..." "$YELLOW"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

cecho "🍺 Installing packages..." "$YELLOW"
./brew.sh
cecho "✅ Finished package installation!" "$GREEN"

#####################################################################################################
# Vim setup                                                                                         #
#####################################################################################################

# Vim plugin manager installation
VIM_AUTOLOAD="$HOME/.vim/autoload"
VIM_PLUG="$VIM_AUTOLOAD/plug.vim"
mkdir -p "$VIM_AUTOLOAD"

if [ ! -f "$VIM_PLUG" ]; then
    cecho "Installing vim plugin manager..." "$YELLOW"
    curl -fLo "$VIM_PLUG" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    [ -f "$VIM_PLUG" ] && cecho "✅ Vim plugin manager installed!" "$GREEN" \
                       || cecho "❌ Failed to install vim plugin manager!" "$RED"
else
    cecho "Vim plugin manager already installed, skipping." "$YELLOW"
fi

cecho "Installing Vim plugins..." "$YELLOW"
vim -es -u "$CONFIGDIR/.vimrc" +PlugInstall +qall
cecho "✅ Vim setup completed!" "$GREEN"

#####################################################################################################
# Post installation                                                                                 #
#####################################################################################################

cecho "✅ Installation finished!" "$GREEN"
