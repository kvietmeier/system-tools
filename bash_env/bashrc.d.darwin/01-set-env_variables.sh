###===============================================================================================###
### Setup Environment Variables
###
###  WARNING: This file can contain sensitive environment variables. Do not share or 
###  commit to public repositories without reviewing and removing sensitive information.
###  Move sensitive variables to ~/.bash_environment.sh or another secure location.
###
###  This file is sourced by ~/.bashrc and ~/.zshrc. It is intended to be used on both
###  macOS and Linux systems. It is also intended to be used on both local and
###  cloud systems. It is not intended to be used on Windows systems.
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
### Canonical private file: ~/.bash_environment.sh  (never commit secrets; .sh for editor formatting)
if [ -f "$HOME/.bash_environment.sh" ]; then
    source "$HOME/.bash_environment.sh"
fi

###===============================================================================================###
### General Environment Variables
###===============================================================================================###

export EDITOR=vim
export VISUAL=vim

export ASCII_LOG_DIR="${HOME}/personal/session_logs"
export CONSOLE_LOGS_DIR="${ASCII_LOG_DIR}"


###===============================================================================================###
### Localized Terraform Directories
###===============================================================================================###
export REPO_DIR="${HOME}/github"
export TFDIR="${REPO_DIR}/Terraform"

export TFVAST="${TFDIR}/vastdata"
export TFGCP="${TFDIR}/gcp/"
export TFAWS="${TFDIR}/aws/"
export TFAZ="${TFDIR}/azure/"

#export VOCDIR="${REPO_DIR}/vast_on_cloud"

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


###===============================================================================================###
### PATH Configuration - Modified for Homebrew
###===============================================================================================###

# Explicitly expose Homebrew GNU coreutils (like gls) to the PATH
PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"

# 1. Initialize Homebrew safely (Only runs on Macs where Brew exists, 
# preventing errors when you sync this file to your Cloud Linux VMs)
if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# 2. Safely prepend personal binary paths individually without stepping on Homebrew
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && PATH="$HOME/.local/bin:$PATH"
[[ ":$PATH:" != *":$HOME/bin:"* ]] && PATH="$HOME/bin:$PATH"


###===============================================================================================###
### Google Cloud SDK Paths
###===============================================================================================###
# Dynamically locate the gcloud SDK bin folder so kubectl can find the auth plugin
if command -v gcloud &> /dev/null; then
    GCLOUD_SDK_BIN="$(gcloud info --format='value(installation.sdk_root)')/bin"
    [[ ":$PATH:" != *":$GCLOUD_SDK_BIN:"* ]] && PATH="$GCLOUD_SDK_BIN:$PATH"
fi

export PATH

