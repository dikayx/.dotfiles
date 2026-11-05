# Linux Mint specific shell settings (linked to ~/.zshrc.os)
alias bubu="sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt clean && (! command -v flatpak >/dev/null || flatpak update -y)"
alias l="ls -la --color=auto"
alias ll="ls -laU --color=auto"
