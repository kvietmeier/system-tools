###===============================================================================================###
### Terminal, History, and Prompt Configuration
### File: .bashrc.d/02-terminal-settings.sh
### 
### Modified for Apple Silicon Mac OS
###
### Purpose: 
###   Configure shell history, colors, aliases, terminal options, and prompt
###
### Created by Karl Vietmeier
### License: Apache 2.0
###===============================================================================================###

# Only run in interactive shells
[[ $- != *i* ]] && return

###===============================================================================================###
### History
###===============================================================================================###
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

###===============================================================================================###
### Terminal Options
###===============================================================================================###
shopt -s checkwinsize        # auto-resize window
set -o vi                    # vi-style editing
bind 'set bell-style none'   # disable terminal bell

# --- Enable Homebrew Advanced Bash Completions
if [[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]]; then
    source "/opt/homebrew/etc/profile.d/bash_completion.sh"
fi

###===============================================================================================###
### Aliases
###===============================================================================================###

# --- Core GNU dircolors integration (Cross-Platform)
if command -v dircolors &> /dev/null; then
    [ -r ~/.dircolors ] && eval "$(dircolors -b ~/.dircolors)"
elif command -v gdircolors &> /dev/null; then
    # Mac/Homebrew coreutils fallback
    [ -r ~/.dircolors ] && eval "$(gdircolors -b ~/.dircolors)"
fi



###===============================================================================================###
### Prompt Configuration
###===============================================================================================###
case "$TERM" in
    xterm-color|*-256color) __color_prompt=yes ;;
    *) __color_prompt=no ;;
esac

if [[ "$__color_prompt" == yes ]]; then
    PS1="\[\033[00;32m\]\u@\h${ENV_TAG}\[\033[00m\]:\[\033[00;34m\]\w\[\033[00m\]\$ "
else
    PS1="\u@\h${ENV_TAG}:\w\$ "
fi
unset __color_prompt


###===============================================================================================###
### Terminal Title (fixed for Mac OS)
###===============================================================================================###
update_terminal_title() {
    # Using $(hostname -s) drops the ugly Apple .local or Wi-Fi DNS suffixes
    printf "\033]0;%s\007" "${USER}@$(hostname -s)${ENV_TAG}: ${PWD}"
}


###===============================================================================================###
### PROMPT_COMMAND
###===============================================================================================###
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

###===============================================================================================###
### Export prompt variables
###===============================================================================================###
export PS1
