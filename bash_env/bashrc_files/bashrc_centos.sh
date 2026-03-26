# .bashrc
# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

###===============================================================================###
###--- History Configuration
###===============================================================================###
# Don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
export HISTSIZE=10000       # Number of commands to keep in memory
export HISTFILESIZE=20000   # Number of commands to store in file
export HISTCONTROL=ignoredups:erasedups
export HISTIGNORE="ls:bg:fg:history"  # Ignore some noisy commands

#--- Share history across terminals
# Use a shared history file
export HISTFILE=~/.bash_history

# Append to the history file, don't overwrite it
shopt -s histappend

# Flush on cd
PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

###=== End History
###===============================================================================###


###===============================================================================###
###--- Setup Color terminal interface
###===============================================================================###
# Enable a fancy prompt with colors if supported
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# Uncomment the following to force color prompt even if TERM isn't ideal
# force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 &>/dev/null; then
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# Enable color support for 'ls' and define useful aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

###--- End Setup Color setup
###===============================================================================###


# Check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Set terminal title to user@host:dir if in xterm/rxvt
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# Source global definitions if they exist
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

set -o vi
bind 'set bell-style none'

###
###------------------- Functions/Aliases --------------------###
###

# Source function definitionms if they exist
if [ -f $HOME/bin/bashfunctions.sh ]; then
    . $HOME/bin/bashfunctions.sh
fi

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
	for rc in ~/.bashrc.d/*; do
		if [ -f "$rc" ]; then
			. "$rc"
		fi
	done
fi
unset rc

# My Aliases
alias l="ls -CFv"
alias la="ls -Av"
alias ls="ls -hF --color=auto"
alias ll='ls -lhvF --group-directories-first'
alias lla='ls -alhvF --group-directories-first'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias grep='grep --color=auto'
alias cdb='cd -'
alias cdu='cd ..'
alias cdu2='cd ../..'
alias cdu3='cd ../../..'
alias df='df -kh'
alias du='du -h'

set -o vi
bind 'set bell-style none'  