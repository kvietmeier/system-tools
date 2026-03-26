###############################################################################
# ~/.bashrc — Unified Ubuntu + Cloud + Productivity Configuration
#
# Description:
#   Provides an interactive shell environment with:
#     - Cloud-aware prompt and terminal title (GCP/AWS/Azure/WSL)
#     - Safe history sync across sessions
#     - Aliases and navigation helpers
#     - Terminal settings (vi mode, auto-resize, bell suppression)
#     - Colorized LS/Grep output
#
# Author: Karl Vietmeier
# License: Apache 2.0 — https://www.apache.org/licenses/LICENSE-2.0
###############################################################################

# ==============================
# 1. INTERACTIVE CHECK
# Only run the rest of the .bashrc if the shell is interactive
[[ $- != *i* ]] && return

# ==============================
# 2. DEBIAN/UBUNTU STANDARD INIT
# Set debian_chroot if running in a chrooted environment
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# Make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ==============================
# 3. HISTORY CONFIGURATION
# Upgraded history management with instant sync
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE="ls:bg:fg:history"
export HISTFILE=~/.bash_history
shopt -s histappend

# Function to sync history across sessions
history_sync() {
    history -a  # append current session to history file
    history -n  # reload new lines from history file
}

# ==============================
# 4. TERMINAL SETTINGS
shopt -s checkwinsize       # Auto-resize window when terminal size changes
set -o vi                   # vi-style command line editing
bind 'set bell-style none' 2>/dev/null  # Disable annoying bell

# ==============================
# 5. CLOUD DETECTION
# Auto-detect cloud environment or WSL
detect_cloud() {
    if [[ -n "$WSL_DISTRO_NAME" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
        echo "WSL"
    elif [[ -d /sys/class/dmi/id ]]; then
        local vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)
        if [[ "$vendor" == *"Microsoft"* ]]; then echo "Azure"
        elif [[ "$vendor" == *"Google"* ]]; then echo "GCP"
        elif [[ "$vendor" == *"Amazon"* ]]; then echo "AWS"
        else echo "OnPrem"; fi
    else
        echo "OnPrem"
    fi
}
CLOUD_PROVIDER=$(detect_cloud)

# ==============================
# 6. COLORS, LS, AND GREP ALIASES
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls -hF --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# ==============================
# 7. PRODUCTIVITY ALIASES
# Directory navigation
alias l='ls -CFv'
alias la='ls -Av'
alias ll='ls -lhvF --group-directories-first'
alias lla='ls -alhvF --group-directories-first'
alias refresh=". ${HOME}/.bashrc"
alias cdb='cd -'
alias up='cd ..'
alias up2='cd ../..'
alias up3='cd ../../..'

# Disk usage
alias df='df -kh'
alias du='du -h'

# Notification for last command
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# ==============================
# 8. PROMPT CONFIGURATION
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes ;;
    *) color_prompt=no ;;
esac

if [ "$color_prompt" = yes ]; then
    PS1="${debian_chroot:+($debian_chroot)}\
\[\033[01;32m\]\u@\h [${CLOUD_PROVIDER}] \[\033[00m\]:\
\[\033[01;34m\]\W\[\033[00m\]\$ "
else
    PS1="${debian_chroot:+($debian_chroot)}\u@\h [${CLOUD_PROVIDER}]:\W\$ "
fi
unset color_prompt

# ==============================
# 9. TERMINAL TITLE (SAFE)
# Sets terminal window title to user@host [Cloud]: current dir
update_terminal_title() {
    printf "\033]0;%s\007" \
        "${debian_chroot:+($debian_chroot)}${USER}@${HOSTNAME} [${CLOUD_PROVIDER}]: ${PWD##*/}"
}

PROMPT_COMMAND="update_terminal_title; history_sync"

# ==============================
# 10. EXTERNAL FILES & COMPLETION
# Load user-specific aliases
[ -f ~/.bash_aliases ] && . ~/.bash_aliases

# Enable programmable completion features
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

###############################################################################
# End of Self-Documenting Unified .bashrc
###############################################################################
