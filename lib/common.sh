#!/bin/bash
# Shared helpers for install.sh and the platform modules (macOS / Linux).
# Sourced, never executed. Keep it bash 3.2 compatible (macOS ships 3.2).

DOTFILES_DIR="$HOME/.dotfiles"
CONFIG_DIR="$DOTFILES_DIR/configs"

### Colors & helpers ###

if [ -t 1 ]; then
    GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
    GREEN=""; YELLOW=""; RED=""; BOLD=""; RESET=""
fi

headline() { printf '%s* %s%s\n' "${BOLD}${GREEN}" "$1" "$RESET"; }
info()     { printf '  %s\n' "$1"; }
warn()     { printf '%s  %s%s\n' "$YELLOW" "$1" "$RESET"; }
error()    { printf '%s%s%s\n' "$RED" "$1" "$RESET" >&2; }
die()      { error "$1"; exit 1; }

# Prints the entries of a manifest file (one per line, '#' starts a comment)
list_entries() { sed 's/#.*//' "$1" | awk 'NF { print $1 }'; }

# symlink <source> <destination> - backs up real files instead of destroying them
symlink() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        mv "$dest" "$dest.bak"
        info "Backed up existing $dest -> $dest.bak"
    fi
    if ln -sfn "$src" "$dest"; then
        info "Linked $dest -> $src"
    else
        error "Failed to link $dest"
    fi
}

### OS detection ###

detect_os() {
    case "$(uname -s)" in
        Darwin) DOTFILES_OS="macos" ;;
        Linux)  DOTFILES_OS="linux" ;;
        *)      die "Unsupported OS '$(uname -s)'. On Windows run install.ps1 instead." ;;
    esac
}

### Command line arguments ###

NEW_HOSTNAME=""
GITNAME=""
GITMAIL=""

show_help() {
    echo "${BOLD}Usage: ./install.sh [OPTIONS]${RESET}"
    echo
    echo "Options:"
    echo "  -hn, --hostname <hostname>  Set the hostname of the system."
    echo "  -gn, --gitname <gitname>    Set the global Git user name."
    echo "  -ge, --gitemail <gitemail>  Set the global Git user email."
    echo "  -h,  --help                 Show this help message and exit."
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -hn|--hostname) [ $# -ge 2 ] || die "Missing value for $1"; NEW_HOSTNAME="$2"; shift 2 ;;
            -gn|--gitname)  [ $# -ge 2 ] || die "Missing value for $1"; GITNAME="$2";      shift 2 ;;
            -ge|--gitemail) [ $# -ge 2 ] || die "Missing value for $1"; GITMAIL="$2";      shift 2 ;;
            -h|--help)      show_help; exit 0 ;;
            *) error "Invalid option: $1"; show_help; exit 1 ;;
        esac
    done

    if [ -n "$NEW_HOSTNAME" ] && ! [[ "$NEW_HOSTNAME" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]; then
        die "Invalid hostname '$NEW_HOSTNAME' (letters, digits and '-' only; no spaces or underscores)."
    fi
}

### Shared installation steps ###

# Links every dotfile from configs/{common,unix,<os>}/ into $HOME.
link_configs() {
    local dir src
    for dir in common unix "$DOTFILES_OS"; do
        [ -d "$CONFIG_DIR/$dir" ] || continue
        while IFS= read -r -d '' src; do
            symlink "$src" "$HOME/$(basename "$src")"
        done < <(find "$CONFIG_DIR/$dir" -maxdepth 1 -type f -name '.*' -print0)
    done
}

# Identity goes to the untracked ~/.gitconfig.local (included by .gitconfig), so the
# tracked config in this repo never gets modified.
set_git_identity() {
    local local_cfg="$HOME/.gitconfig.local"
    if [ -n "$GITNAME" ]; then git config --file "$local_cfg" user.name "$GITNAME"; fi
    if [ -n "$GITMAIL" ]; then git config --file "$local_cfg" user.email "$GITMAIL"; fi
    return 0
}

setup_vim() {
    local plug_file="$HOME/.vim/autoload/plug.vim"

    if [ ! -f "$plug_file" ]; then
        info "Installing vim plugin manager ..."
        if curl -fLo "$plug_file" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; then
            info "Vim plugin manager installed."
        else
            error "Failed to install vim plugin manager!"
        fi
    else
        info "Vim plugin manager already installed, skipping."
    fi

    info "Installing Vim plugins ..."
    vim -es -u "$CONFIG_DIR/common/.vimrc" +PlugInstall +qall </dev/null \
        || warn "Vim plugin installation reported an error."
    return 0
}
