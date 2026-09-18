###############################################################################
# bashrc_lab_server.sh — Universal drop-in ~/.bashrc for lab / cloud VMs
#
# Purpose:
#   Quick interactive shell setup on a new Ubuntu, RHEL/CentOS, or cloud VM:
#     - Cloud-aware prompt + terminal title (GCP / AWS / Azure / WSL / OnPrem)
#     - Shared history sync, vi editing, sensible aliases
#     - Optional ~/.bashrc.d fragments and ~/.bash_aliases
#
# Install (as the lab user):
#   curl -fsSL <raw-url> -o ~/.bashrc
#   # or:  scp bashrc_lab_server.sh user@host:~/.bashrc
#   source ~/.bashrc
#
# Author: Karl Vietmeier
# License: Apache 2.0
###############################################################################

# Only configure interactive shells
[[ $- != *i* ]] && return

###-----------------------------------------------------------------------------###
### Distro hooks
###-----------------------------------------------------------------------------###
# Debian/Ubuntu chroot label (harmless elsewhere)
if [[ -z "${debian_chroot:-}" && -r /etc/debian_chroot ]]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# RHEL/CentOS/Fedora system bashrc
[[ -f /etc/bashrc ]] && . /etc/bashrc

# lesspipe when available
[[ -x /usr/bin/lesspipe ]] && eval "$(SHELL=/bin/sh lesspipe)"

# User local bins (common on both families)
if [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]]; then
    PATH="${HOME}/.local/bin:${PATH}"
fi
if [[ ":${PATH}:" != *":${HOME}/bin:"* ]]; then
    PATH="${HOME}/bin:${PATH}"
fi
export PATH

###-----------------------------------------------------------------------------###
### History
###-----------------------------------------------------------------------------###
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE="ls:bg:fg:history"
export HISTFILE="${HOME}/.bash_history"
shopt -s histappend

history_sync() {
    history -a
    history -n
}

###-----------------------------------------------------------------------------###
### Terminal
###-----------------------------------------------------------------------------###
shopt -s checkwinsize
set -o vi
bind 'set bell-style none' 2>/dev/null || true

###-----------------------------------------------------------------------------###
### Cloud / environment tag
###-----------------------------------------------------------------------------###
# Prefer explicit ENV_TAG, then Lima instance name, then DMI / vendor.
detect_cloud() {
    if [[ -n "${ENV_TAG:-}" ]]; then
        echo "${ENV_TAG}"
        return
    fi

    # Lima default hostname is lima-<instance> (e.g. lima-aws-env → aws-env)
    local host
    host=$(hostname -s 2>/dev/null || hostname)
    if [[ "$host" == lima-* ]]; then
        echo "${host#lima-}"
        return
    fi

    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
        echo "WSL"
        return
    fi

    local product vendor
    if [[ -r /sys/class/dmi/id/product_name ]]; then
        product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
        case "$product" in
            "Google Compute Engine") echo "GCP"; return ;;
            "Virtual Machine")       echo "Azure"; return ;;
            "HVM domU"|*"Amazon EC2"*) echo "AWS"; return ;;
        esac
    fi

    if [[ -r /sys/class/dmi/id/sys_vendor ]]; then
        vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)
        case "$vendor" in
            *Google*)    echo "GCP"; return ;;
            *Microsoft*) echo "Azure"; return ;;
            *Amazon*)    echo "AWS"; return ;;
        esac
    fi

    echo "OnPrem"
}

CLOUD_PROVIDER=$(detect_cloud)
export CLOUD_PROVIDER
export ENV_TAG="${ENV_TAG:-$CLOUD_PROVIDER}"

###-----------------------------------------------------------------------------###
### Colors + aliases
###-----------------------------------------------------------------------------###
if [[ -x /usr/bin/dircolors ]]; then
    if [[ -r "${HOME}/.dircolors" ]]; then
        eval "$(dircolors -b "${HOME}/.dircolors")"
    else
        eval "$(dircolors -b)"
    fi
fi

alias ls='ls -hF --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias l='ls -CFv'
alias la='ls -Av'
alias ll='ls -lhvF --group-directories-first'
alias lla='ls -alhvF --group-directories-first'

alias refresh=". ${HOME}/.bashrc"
alias cdb='cd -'
alias up='cd ..'
alias up2='cd ../..'
alias up3='cd ../../..'
alias cdu='cd ..'
alias cdu2='cd ../..'
alias cdu3='cd ../../..'

alias df='df -kh'
alias du='du -h'

# Desktop notify helper — only if notify-send exists (skip on headless VMs)
if command -v notify-send &>/dev/null; then
    alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
fi

###-----------------------------------------------------------------------------###
### Prompt + window title
###-----------------------------------------------------------------------------###
case "$TERM" in
    xterm-color|*-256color) __color_prompt=yes ;;
    *) __color_prompt=no ;;
esac

if [[ "$__color_prompt" == yes ]]; then
    PS1="${debian_chroot:+($debian_chroot)}\
\[\033[01;32m\]\u@\h [${CLOUD_PROVIDER}]\[\033[00m\]:\
\[\033[01;34m\]\W\[\033[00m\]\$ "
else
    PS1="${debian_chroot:+($debian_chroot)}\u@\h [${CLOUD_PROVIDER}]:\W\$ "
fi
unset __color_prompt

update_terminal_title() {
    printf "\033]0;%s\007" \
        "${debian_chroot:+($debian_chroot)}${USER}@${HOSTNAME} [${CLOUD_PROVIDER}]: ${PWD##*/}"
}

PROMPT_COMMAND="update_terminal_title; history_sync"

###-----------------------------------------------------------------------------###
### Optional extensions
###-----------------------------------------------------------------------------###
[[ -f "${HOME}/.bash_aliases" ]] && . "${HOME}/.bash_aliases"

if [[ -f "${HOME}/bin/bashfunctions.sh" ]]; then
    . "${HOME}/bin/bashfunctions.sh"
fi

if [[ -d "${HOME}/.bashrc.d" ]]; then
    shopt -s nullglob
    for rc in "${HOME}/.bashrc.d"/*; do
        [[ -f "$rc" ]] && . "$rc"
    done
    shopt -u nullglob
    unset rc
fi

if ! shopt -oq posix; then
    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        . /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        . /etc/bash_completion
    fi
fi

###############################################################################
# End of lab server ~/.bashrc
###############################################################################
