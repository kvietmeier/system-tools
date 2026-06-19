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
    # --- Refresh .bashrc
    alias profile=". ${HOME}/.bash_profile"
    
    # --- List functions
    alias shwf="declare -F"

    # --- Smarter ls commands (Cross-Platform via Homebrew gls)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Force the GNU engine to use auto-colors so piping to grep doesn't break
        alias ls='gls -hF --color=auto'
        alias l='gls -CFv --color=auto'
        alias la='gls -Av --color=auto'
        alias ll='gls -lhvF --group-directories-first --color=auto'
        alias lla='gls -alhvF --group-directories-first --color=auto'
        
        # Only alias 'code' manually if it isn't already in the system PATH
        if ! command -v code &> /dev/null; then
            alias code="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
        fi
    else
        # Standard Linux Engine
        alias ls='ls -hF --color=auto'
        alias l='ls -CFv'
        alias la='ls -Av'
        alias ll='ls -lhvF --group-directories-first'
        alias lla='ls -alhvF --group-directories-first'
    fi

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

    # Utilities for getting public IP
    alias myip=get_my_ip
 
    # --- Include user-defined aliases if present
    [ -f "${HOME}/.bash_aliases" ] && . "${HOME}/.bash_aliases"
}

# Call the function automatically on shell startup
load_aliases