### Basic prompt settings ###

# Load version control information
autoload -Uz vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )

# Load color & theme information
autoload -U colors && colors

# Set up prompt (w/ theme & git branch name)
setopt PROMPT_SUBST

# Change VCS symbol based on git status
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' stagedstr '!'
zstyle ':vcs_info:*' unstagedstr '*'

### Prompt theme ###

# PRECMD: Controls blank lines before prompts
precmd() {
    # If 'clear' was just run, skip printing a blank line
    if [[ "$CLEAR_TRIGGER" == 1 ]]; then
        CLEAR_TRIGGER=0
        return
    fi

    # After the 1st prompt, always print a blank line before each prompt
    if [[ -n "$_HAS_PROMPTED_ONCE" ]]; then
        echo ""
    else
        _HAS_PROMPTED_ONCE=1
    fi
}

# PREEXEC: Detect commands before execution
preexec() {
    if [[ "$1" == "clear" ]]; then
        CLEAR_TRIGGER=1
    fi
}

# Pure prompt theme
PROMPT=$'%F{014}%c%f${vcs_info_msg_0_}\n%(!.#.%F{046}❯%f) '

# VCS (Git) style
zstyle ':vcs_info:git:*' formats ' %F{032}git%f:(%F{011}%b%u%c%f)'

### Shortcuts & aliases ###

# Aliases
alias bubu="brew update && brew upgrade -y && brew autoremove && brew cleanup"
alias gpgf="git pull && git fetch"
alias l="ls -lGa"
alias ll="ls -lGaf"

# Custom scripts
_SCRIPTS_DIR="${ZDOTDIR:-$HOME}/.dotfiles/scripts"
alias cleanup="zsh ${_SCRIPTS_DIR}/cleanup.sh"
alias chkbrew="zsh ${_SCRIPTS_DIR}/chkbrew.sh"
alias chkdsk="zsh ${_SCRIPTS_DIR}/chkdsk.sh"
