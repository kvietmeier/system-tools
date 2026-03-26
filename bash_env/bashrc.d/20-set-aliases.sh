###############################################################################
### Bash Aliases and Productivity Helpers
### File: .bashrc.d/20-set-aliases.sh
### Purpose: 
###   Load Linux productivity, VoC, Terraform, and cloud SDK aliases
###   All aliases are loaded only if the corresponding tools exist
### Created by Karl Vietmeier
### License: Apache 2.0
###############################################################################

# Load aliases only if the corresponding tools are installed, and 
# include user-defined aliases if present
load_aliases() {

    # --- Desktop Notifications for long-running commands
    alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" \
      "$(history | tail -n1 | sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

    # --- Refresh .bashrc
    alias refresh=". ${HOME}/.bashrc"

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

    # --- Terraform / VoC aliases only if Terraform is installed
    if command -v terraform >/dev/null 2>&1; then

        ###--- Terraform convenience aliases
        alias tfclean='tfclean'
        alias tfclstate='tfclstate'
        alias tfinit='tfinit'
        alias tfshow='tfshow'
        alias tfapply='tfapply'
        alias tfdestroy='tfdestroy'
        alias tfplan='tfplan'

        ###--- Output helper aliases
        alias vms='tf_vms'
        alias vmsmon='tf_vmsmon'
        alias vmsip='tf_vmsip'
        alias eboxips='tf_private_ips'

        # VAST Terraform / VoC shortcuts
        alias vasttf="cd ${VASTTF_ROOT}"          # VAST Terraform root
        alias vocdir="cd ${TFDIR}/vast_on_cloud/5_3"
        alias vastdir="cd ${VASTTF_ROOT}"
        alias cluster01="cd ${VASTGCP}/cluster01"
        alias cluster02="cd ${VASTGCP}/cluster02"
        alias cluster03="cd ${VASTGCP}/cluster03"

        # Optional VoC scripts
        alias install_vast01="${HOME}/bin/vast.voc.install.py"
        alias pgpsecrets="${HOME}/Terraform/scripts/vast.extracts3secret.sh"
        alias vmsstat="${HOME}/bin/vms.status.py"
    fi

    # --- AWS aliases if AWS CLI exists
    if command -v aws >/dev/null 2>&1; then
        alias awslogin=aws_sso_login
        alias awscheck=aws_check_all_profiles
        alias awslist=aws_list_profiles
        alias awsversion=aws_cli_version
        alias awslogout=aws_sso_logout
    fi

    # --- GCP aliases if gcloud exists
    if command -v gcloud >/dev/null 2>&1; then
        alias gcpinstances=GCPListInstances
        alias gcpsubnets=GCPListSubnets
        alias gcporphanroutes=GCPGetOrphanedRoutesCore
        alias gcporphan=GCPGetOrphanedRoutes
        alias gcptoken=GCPGetAccessToken
        alias gcpuser=GCPGetCoreAcct
        alias gcproj=GCPGetProject
        alias gcloud="$GCLOUD_CMD"
    fi

    # --- Azure aliases if az exists
    if command -v az >/dev/null 2>&1; then
        alias azdisks=list_azdisks
        alias azvms=list_azvms
        alias azsubnets=list_azsubnets
        alias azvnets=list_azvnets
        alias azlogin=azlogin
        alias azlogout=azlogout
        alias azshow=azshow
        alias azcontext=azcontext
    fi

    # --- Include user-defined aliases if present
    [ -f "${HOME}/.bash_aliases" ] && . "${HOME}/.bash_aliases"
}

# Call the function automatically on shell startup
load_aliases