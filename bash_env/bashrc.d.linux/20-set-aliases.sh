###=================================================================================================###
### Bash Aliases and Productivity Helpers
### File: .bashrc.d/20-set-aliases.sh
### Purpose: 
###   Load Linux productivity, VoC, Terraform, and cloud SDK aliases
###   All aliases are loaded only if the corresponding tools exist
### Created by Karl Vietmeier
### License: Apache 2.0
###=================================================================================================###

# include user-defined aliases if present
load_aliases() {
    # --- Desktop Notifications for long-running commands
    alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" \
      "$(history | tail -n1 | sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

    # --- Refresh .bashrc
    alias dotbash=". ${HOME}/.bashrc"
    
    # --- List functions
    alias shwf="declare -F"

    # --- Smarter ls commands
    alias ls='ls -hF --color=auto'
    alias l='ls -CFv'
    alias la='ls -Av'
    alias ll='ls -lhvF --group-directories-first'
    alias lla='ls -alhvF --group-directories-first'

    # --- Grep with colors
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'

    # --- Git helpers
    alias gitsync="${HOME}/bin/git-sync.sh"
    alias gpush="${HOME}/bin/git-sync.sh push"
    alias gpull="${HOME}/bin/git-sync.sh pull"
    alias gstat="${HOME}/bin/git-sync.sh status"

    # --- Quick directory navigation
    alias cdb='cd -'
    alias up='cd ..'
    alias up2='cd ../..'
    alias up3='cd ../../..'

    # --- Disk usage
    alias df='df -kh'
    alias du='du -h'

    # Utlities for getting public IP
    alias myip=get_my_ip

    # --- Include user-defined aliases if present
    [ -f "${HOME}/.bash_aliases" ] && . "${HOME}/.bash_aliases"
}

# Call the function automatically on shell startup
load_aliases