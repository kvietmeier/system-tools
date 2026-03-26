###############################################################################
### Terminal, History, and Prompt Configuration
### File: .bashrc.d/02-terminal-settings.sh
### Purpose: 
###   Configure shell history, colors, aliases, terminal options, and prompt
### Created by Karl Vietmeier
### License: Apache 2.0
###############################################################################

# Only run in interactive shells
[[ $- != *i* ]] && return

###############################################################################
### History
###############################################################################
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE="ls:bg:fg:history"
export HISTFILE=~/.bash_history

# Append to history and read new lines immediately
history_sync() {
    history -a
    history -n
}

###############################################################################
### Terminal Options
###############################################################################
shopt -s checkwinsize        # auto-resize window
set -o vi                    # vi-style editing
bind 'set bell-style none'   # disable terminal bell

###############################################################################
### Aliases
###############################################################################
if [ -x /usr/bin/dircolors ]; then
    if [ -r ~/.dircolors ]; then
        eval "$(dircolors -b ~/.dircolors)"
    else
        eval "$(dircolors -b)"
    fi
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

alias ls='ls -hF --color=auto'
alias l='ls -CFv'
alias la='ls -Av'
alias ll='ls -lhvF --group-directories-first'
alias lla='ls -alhvF --group-directories-first'
alias df='df -kh'
alias du='du -h'
alias up='cd ..'
alias up2='cd ../..'
alias up3='cd ../../..'
alias refresh=". ${HOME}/.bashrc"

###############################################################################
### Prompt Configuration
###############################################################################
case "$TERM" in
    xterm-color|*-256color) __color_prompt=yes ;;
    *) __color_prompt=no ;;
esac

if [[ "$__color_prompt" == yes ]]; then
    PS1="\[\033[01;32m\]\u@\h${ENV_TAG}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
else
    PS1="\u@\h${ENV_TAG}:\w\$ "
fi
unset __color_prompt

###############################################################################
### Terminal Title
###############################################################################
update_terminal_title() {
    printf "\033]0;%s\007" "${USER}@${HOSTNAME}${ENV_TAG}: ${PWD}"
}

###############################################################################
### PROMPT_COMMAND
###############################################################################
# Append our functions safely to PROMPT_COMMAND
case "$PROMPT_COMMAND" in
    *history_sync*) ;;
    *)
        if [[ -n "$PROMPT_COMMAND" ]]; then
            PROMPT_COMMAND="history_sync; update_terminal_title; $PROMPT_COMMAND"
        else
            PROMPT_COMMAND="history_sync; update_terminal_title"
        fi
        ;;
esac

###############################################################################
### Export prompt variables
###############################################################################
export PS1
export PROMPT_COMMAND