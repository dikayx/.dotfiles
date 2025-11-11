#####################################################################################
# Basic prompt settings:                                                            #
#####################################################################################

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

#####################################################################################
# Prompt themes:                                                                    #
#####################################################################################

function precmd() {
    # Print a newline before the prompt, unless it's the first prompt in the process.
    if [ -z "$NEW_LINE_BEFORE_PROMPT" ]; then
        NEW_LINE_BEFORE_PROMPT=1
    elif [ "$NEW_LINE_BEFORE_PROMPT" -eq 1 ]; then
        echo ""
    fi
}

# Pure prompt theme
NEWLINE=$'\n'
PROMPT='%F{014}%c%f${vcs_info_msg_0_}${NEWLINE}%(!.#.%F{046}❯%f) '
# VCS (Git) style
zstyle ':vcs_info:git:*' formats ' %F{032}git%f:(%F{011}%b%u%c%f)'

#####################################################################################
# Shortcuts & aliases:                                                              #
#####################################################################################

# Aliases
alias gpgf="git pull && git fetch"
alias bubu="brew update && brew upgrade && brew cleanup"
alias gclone='f(){ git clone "$1" && cd "$(basename "$1" .git)" && code .; }; f'

