#!/bin/bash
# macOS platform module - sourced by install.sh. Implements the platform_* hooks.

MACOS_DIR="$DOTFILES_DIR/platforms/macos"

platform_set_hostname() {
    info "Changing hostname to $1"
    # Setting all 3 hostname types for network consistency
    local key
    for key in ComputerName HostName LocalHostName; do
        sudo scutil --set "$key" "$1"
    done
}

platform_prepare() {
    if [ "$(uname -m)" = "arm64" ]; then
        if pgrep -q oahd; then
            info "Rosetta 2 already installed, skipping."
        else
            info "Apple Silicon Mac detected. Installing Rosetta 2 ..."
            sudo softwareupdate --install-rosetta --agree-to-license
        fi
    fi
}

platform_install_packages() {
    if ! command -v brew &> /dev/null; then
        info "Installing Homebrew ..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # A fresh install is not on PATH yet in this session (configs/macos/.zprofile does it for new shells)
        if [ -x /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi

    info "Updating Homebrew ..."
    brew update

    info "Installing packages from Brewfile ..."
    HOMEBREW_NO_ASK=1 HOMEBREW_BUNDLE_NO_UPGRADE=1 brew bundle install --file="$MACOS_DIR/Brewfile"

    info "Cleaning up ..."
    brew cleanup
}

platform_setup_terminal() {
    local profile_file="$MACOS_DIR/Predawn.terminal"
    local profile_name
    profile_name=$(plutil -extract name raw -o - "$profile_file" 2>/dev/null || true)

    if [ -n "$profile_name" ]; then
        info "Importing Terminal profile ${profile_name} ..."
        open "$profile_file"
        sleep 1
        defaults write com.apple.Terminal "Default Window Settings" -string "$profile_name"
        defaults write com.apple.Terminal "Startup Window Settings" -string "$profile_name"
    else
        error "Could not read profile name from $profile_file"
    fi
}

platform_finish() { :; }
