#!/bin/zsh

#####################################################################################################
# makevenv — create a Python virtual environment                                                    #
#####################################################################################################

# This script creates a Python virtual environment (or detect an existing one), then tell you how to 
# activate it.
#
# Usage:
#   makevenv [path]     # default: ${MAKEVENV_DEFAULT_DIR:-.venv}
#   makevenv -h

#####################################################################################################
# Helpers                                                                                           #
#####################################################################################################

_ok()   { print -P "%F{green}✓%f $1" }
_info() { print -P "%F{cyan}➜%f $1" }
_warn() { print -P "%F{yellow}!%f $1" }
_err()  { print -P "%F{red}✗%f $1" }

_confirm() {
    print -n "$1 [y/n] "
    read -q REPLY
    local rv=$?
    print ""
    return $rv
}

#####################################################################################################
# Check for flags                                                                                    #
#####################################################################################################

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    print "Usage: makevenv [path]"
    print "  Creates a venv at <path> (default: \${MAKEVENV_DEFAULT_DIR:-.venv})"
    print "  if none exists yet, or reports one that's already there."
    exit 0
fi

#####################################################################################################
# Prerequisites                                                                                     #
#####################################################################################################

venv_dir="${1:-${MAKEVENV_DEFAULT_DIR:-.venv}}"
venv_dir="${venv_dir/#\~/$HOME}"       # expand a leading ~

# Already inside a venv? just a heads-up, doesn't block anything
if [[ -n "$VIRTUAL_ENV" ]]; then
    _warn "Heads up: you're currently inside a virtual environment: $VIRTUAL_ENV"
    if ! _confirm "Continue anyway?"; then
        _info "Aborting."
        exit 1
    fi
fi

# Check if target directory exists
if [[ -e "$venv_dir" && ! -d "$venv_dir" ]]; then
    _err "'$venv_dir' already exists and is not a directory."
    exit 1
fi

activate_script="$venv_dir/bin/activate"

if [[ -d "$venv_dir" ]]; then
    if [[ -f "$activate_script" ]]; then
        _info "A virtual environment already exists at '$venv_dir'."
    else
        _warn "'$venv_dir' exists but doesn't look like a valid venv (no bin/activate)."
        if _confirm "Delete it and create a fresh venv there?"; then
            rm -rf "$venv_dir" || { _err "Could not remove '$venv_dir' — check permissions."; exit 1; }
        else
            _info "Aborting without changes."
            exit 1
        fi
    fi
fi

#####################################################################################################
# Python checks                                                                                     #
#####################################################################################################

if [[ ! -d "$venv_dir" ]]; then
    # Find a Python 3 interpreter
    python_bin=""
    for candidate in python3 python; do
        if command -v "$candidate" >/dev/null 2>&1; then
            python_bin="$candidate"
            break
        fi
    done

    if [[ -z "$python_bin" ]]; then
        _err "No Python interpreter found on PATH. Install it, e.g.: brew install python"
        exit 1
    fi

    pymajor=$("$python_bin" -c 'import sys; print(sys.version_info[0])' 2>/dev/null)
    if [[ "$pymajor" != "3" ]]; then
        _err "'$python_bin' is Python $pymajor, but Python 3 is required."
        exit 1
    fi

    if ! "$python_bin" -c "import venv" >/dev/null 2>&1; then
        _err "The 'venv' module is not available for $("$python_bin" --version 2>&1)."
        exit 1
    fi

    _ok "Using $("$python_bin" --version 2>&1) ($(command -v "$python_bin"))"

    # Make sure the parent directory exists & is writable
    parent_dir=$(dirname "$venv_dir")
    [[ -z "$parent_dir" ]] && parent_dir="."

    if [[ ! -d "$parent_dir" ]]; then
        _info "Creating parent directory '$parent_dir'..."
        mkdir -p "$parent_dir" || { _err "Could not create '$parent_dir'."; exit 1; }
    fi

    if [[ ! -w "$parent_dir" ]]; then
        _err "No write permission in '$parent_dir'."
        exit 1
    fi

    # Create the venv
    _info "Creating virtual environment in '$venv_dir'..."
    if ! "$python_bin" -m venv "$venv_dir"; then
        [[ -d "$venv_dir" ]] && rm -rf "$venv_dir"
        _err "Failed to create the virtual environment."
        exit 1
    fi

    if [[ ! -f "$activate_script" ]]; then
        _err "Venv was created but the activate script is missing — something went wrong."
        exit 1
    fi

    _ok "Created a new virtual environment at '$venv_dir'."

    # Keep pip current, but don't fail the whole thing if this hiccups
    "$python_bin" -m pip install --upgrade pip --quiet 2>/dev/null
fi

#####################################################################################################
# Final instructions                                                                                #
#####################################################################################################
if command -v pbcopy >/dev/null 2>&1; then
    print -n "$activate_script" | pbcopy
    _ok "Copied '$activate_script' to the clipboard."
fi

print ""
_ok "To activate it, run:"
print "  source '$activate_script'"
