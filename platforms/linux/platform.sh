#!/bin/bash
# Linux Mint platform module - sourced by install.sh. Implements the platform_* hooks.
# Works on any apt based distribution, but is written and tested for Linux Mint.

LINUX_DIR="$DOTFILES_DIR/platforms/linux"
# Fixed profile id, so re-running the installer updates the profile instead of duplicating it
TERMINAL_PROFILE_UUID="5d0c3f5e-7a3b-4c1e-9f4a-6b1f2e8d9a10"

_require_apt() {
    command -v apt-get >/dev/null 2>&1 || die "apt-get not found. This setup supports Linux Mint (apt based systems)."
}

platform_set_hostname() {
    info "Changing hostname to $1"
    sudo hostnamectl set-hostname "$1"
    # Keep /etc/hosts in sync, otherwise sudo complains about an unresolvable host
    if grep -q '^127\.0\.1\.1' /etc/hosts; then
        sudo sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$1/" /etc/hosts
    else
        printf '127.0.1.1\t%s\n' "$1" | sudo tee -a /etc/hosts >/dev/null
    fi
}

platform_prepare() {
    _require_apt
    # shellcheck disable=SC1091
    . /etc/os-release
    if [ "${ID:-}" != "linuxmint" ]; then
        warn "Not running Linux Mint (detected: ${PRETTY_NAME:-unknown}). Continuing, since apt is available."
    fi
    info "Refreshing package lists ..."
    sudo apt-get update
    sudo apt-get install -y curl ca-certificates gnupg software-properties-common
}

_apt_install_list() {
    local pkgs pkg
    pkgs=$(list_entries "$1" | tr '\n' ' ')
    # shellcheck disable=SC2086
    if sudo apt-get install -y $pkgs; then return 0; fi
    warn "Bulk install failed - retrying package by package ..."
    for pkg in $pkgs; do
        sudo apt-get install -y "$pkg" || warn "Could not install $pkg"
    done
}

_add_vscode_repo() {
    [ -f /etc/apt/sources.list.d/vscode.list ] && return 0
    info "Adding the Microsoft VS Code repository ..."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/microsoft.gpg >/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    sudo apt-get update
}

_install_gcm() {
    if command -v git-credential-manager >/dev/null 2>&1; then
        info "Git Credential Manager already installed, skipping."
        return 0
    fi
    info "Installing Git Credential Manager ..."
    local arch deb_url deb_file
    arch=$(dpkg --print-architecture)
    deb_url=$(curl -fsSL https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest \
        | grep -oE "https://[^\"]+gcm-linux[_-]${arch}[^\"]*\.deb" | head -1 || true)
    if [ -z "$deb_url" ]; then
        warn "Could not find a Git Credential Manager package for $arch - skipping."
        return 0
    fi
    deb_file="$(mktemp -d)/gcm.deb"
    if ! { curl -fsSL -o "$deb_file" "$deb_url" && sudo apt-get install -y "$deb_file"; }; then
        warn "Git Credential Manager installation failed."
    fi
}

platform_install_packages() {
    # fastfetch is not in the repositories of older Ubuntu / Mint releases
    if ! apt-cache show fastfetch >/dev/null 2>&1; then
        info "Adding the fastfetch PPA ..."
        sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch || warn "Could not add the fastfetch PPA."
        sudo apt-get update
    fi

    info "Installing packages from packages.apt ..."
    _apt_install_list "$LINUX_DIR/packages.apt"

    info "Installing Visual Studio Code ..."
    _add_vscode_repo
    sudo apt-get install -y code || warn "Could not install Visual Studio Code."

    _install_gcm

    if command -v flatpak >/dev/null 2>&1; then
        info "Installing Flatpak apps ..."
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        local app
        for app in $(list_entries "$LINUX_DIR/flatpaks.txt"); do
            flatpak install -y --noninteractive flathub "$app" || warn "Could not install $app"
        done
    else
        warn "flatpak not found - skipping Flatpak apps (Discord, Spotify)."
    fi

    info "Cleaning up ..."
    sudo apt-get autoremove -y
    sudo apt-get clean
}

platform_setup_terminal() {
    if ! command -v dconf >/dev/null 2>&1 || ! command -v gnome-terminal >/dev/null 2>&1; then
        warn "gnome-terminal / dconf not found - skipping terminal profile."
        return 0
    fi
    if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        warn "No desktop session bus available (are you in SSH?) - skipping terminal profile."
        return 0
    fi

    local base="/org/gnome/terminal/legacy/profiles:/" list new_list
    info "Importing gnome-terminal profile Predawn ..."
    dconf load "$base" < "$LINUX_DIR/predawn.dconf"

    list=$(dconf read "${base}list" || true)
    if [ -z "$list" ]; then
        new_list="['$TERMINAL_PROFILE_UUID']"
    elif [[ "$list" == *"$TERMINAL_PROFILE_UUID"* ]]; then
        new_list="$list"
    else
        new_list="${list%]*}, '$TERMINAL_PROFILE_UUID']"
    fi
    dconf write "${base}list" "$new_list"
    dconf write "${base}default" "'$TERMINAL_PROFILE_UUID'"
}

platform_finish() {
    local zsh_path
    zsh_path=$(command -v zsh || true)
    if [ -n "$zsh_path" ] && [ "$(basename "${SHELL:-}")" != "zsh" ]; then
        info "Setting zsh as the login shell ..."
        sudo chsh -s "$zsh_path" "$USER" || warn "Could not change the login shell."
        info "Log out and back in for the new shell to take effect."
    fi
}
