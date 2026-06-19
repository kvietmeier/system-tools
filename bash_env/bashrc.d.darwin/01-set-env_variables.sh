###===============================================================================================###
### Setup Environment Variables
###
###  WARNING: This file can contain sensitive environment variables. Do not share or 
###  commit to public repositories without reviewing and removing sensitive information.
###  Move sensitive variables to ~/.bash_environment or another secure location.
###
###===============================================================================================###
### Modified for Apple Silicon Mac OS
###
### The /sys/class/dmi/... checks: macOS does not use the Linux /sys virtual filesystem.
### The /proc/version checks: macOS does not use /proc.
### GCLOUD_CMD="/usr/bin/gcloud": Homebrew installs gcloud into /opt/homebrew/bin/gcloud. 
### Hardcoding the Linux path will break your GCP functions later.
###
### File: .bashrc.d/01-set-env_variables.sh
### Purpose:
###   Sets PATH, general environment variables,
###   environment detection, and sources personal variables.
### Created by Karl Vietmeier
### License: Apache 2.0
###===============================================================================================###

### Source local environment variables from a separate file for security
if [ -f "$HOME/.bash_environment" ]; then
    source "$HOME/.bash_environment"
fi

###===============================================================================================###
### PATH Configuration - Modified for Homebrew
###===============================================================================================###

# Safely prepend personal binary paths individually without stepping on Homebrew
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && PATH="$HOME/.local/bin:$PATH"
[[ ":$PATH:" != *":$HOME/bin:"* ]] && PATH="$HOME/bin:$PATH"

export PATH

###===============================================================================================###
### General Environment Variables
###===============================================================================================###

export EDITOR=vim
export VISUAL=vim

export ASCII_LOG_DIR="repos/personal/session_logs"
export CONSOLE_LOGS_DIR="${HOME}/${ASCII_LOG_DIR}"


###===============================================================================================###
### Localized Terraform Directories
###===============================================================================================###
export REPO_DIR="${HOME}/repos"
export TFDIR="${REPO_DIR}/Terraform"
export VASTTF="${TFDIR}/vastdata"
export VOCDIR="${REPO_DIR}/vast_on_cloud"

export TFGCP="${TFDIR}/gcp/"
export TFAWS="${TFDIR}/aws/"
export TFAZ="${TFDIR}/azure/"


###===============================================================================================###
### Environment Tag: Mac Local / Cloud
###===============================================================================================###
ENV_TAG=""

# macOS (Darwin) detection
if [[ "$(uname -s)" == "Darwin" ]]; then
    ENV_TAG=" [Local] "

# Cloud VM detection (if synced to remote Linux nodes)
elif [[ -r /sys/class/dmi/id/product_name ]]; then
    product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
    case "$product_name" in
        "Virtual Machine")        ENV_TAG=" [Azure] " ;;
        "Google Compute Engine")  ENV_TAG=" [GCP] " ;;
        "HVM domU")               ENV_TAG=" [AWS] " ;;
    esac
fi

export ENV_TAG

# Explicitly expose Homebrew GNU coreutils (like gls) to the PATH
PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"


