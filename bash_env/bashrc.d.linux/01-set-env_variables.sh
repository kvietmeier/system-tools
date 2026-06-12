###===============================================================================================###
### Setup Environment Variables
### File: .bashrc.d/01-set-env_variables.sh
### Purpose:
###   Sets PATH, general environment variables,
###   environment detection, and sources personal variables.
### Created by Karl Vietmeier
### License: Apache 2.0
###===============================================================================================###

###===============================================================================================###
### PATH Configuration
###===============================================================================================###

case ":$PATH:" in
  *":$HOME/.local/bin:$HOME/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$HOME/bin:$PATH" ;;
esac
export PATH

###===============================================================================================###
### General Environment Variables
###===============================================================================================###

export EDITOR=vim
export VISUAL=vim

# Enable session logging with script, but only if not already enabled to avoid nesting

# For storing logs from script
# Note: This is a custom variable for my scripts to know where to save session logs.
export ASCII_LOG_DIR="projects/personal/session_logs"
export CONSOLE_LOGS_DIR="${HOME}/${ASCII_LOG_DIR}"


###===============================================================================================###
### Localized Terraform Directories
###===============================================================================================###
# Directory where all repositories are stored
export REPO_DIR="${HOME}/projects"

# Shotrcut variables for Terraform and VoC directories within the repository
export TFDIR="${REPO_DIR}/Terraform"
export VASTTF="${TFDIR}/vastdata"
export VOCDIR="${REPO_DIR}/vast_on_cloud"

export TFGCP="${TFDIR}/gcp/"
export TFAWS="${TFDIR}/aws/"
export TFAZ="${TFDIR}/azure/"

###===============================================================================================###
### Google Cloud SDK Configuration - WSL
###===============================================================================================###
# Needed for gcloud CLI to find the correct Python interpreter in WSL 
# and avoid conflicts with Windows Python installations - works for all Distro
export GCLOUD_CMD="/usr/bin/gcloud"

###===============================================================================================###
### Environment Tag: WSL / Cloud / Local
###===============================================================================================###
ENV_TAG=""

# WSL detection
if [[ -n "$WSL_DISTRO_NAME" ]]; then
    ENV_TAG=" [WSL] "

# Cloud VM detection by product_name
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
### WSL-Specific Adjustments
###===============================================================================================###
if grep -qi microsoft /proc/version 2>/dev/null; then

    for win_path in \
        "/mnt/c/Users/karl.vietmeier/AppData/Local/Google/Cloud SDK/google-cloud-sdk/bin" \
        "/mnt/c/Program Files (x86)/Google/Cloud SDK/google-cloud-sdk/bin" \
        "/mnt/c/Program Files/Google/Google Apps Sync/"; do

        PATH=$(echo "$PATH" | tr ':' '\n' | grep -vF "$win_path" | tr '\n' ':' | sed 's/:$//')
    done

    export PATH

    if command -v wslview >/dev/null 2>&1; then
        export BROWSER=wslview
    fi
fi

###===============================================================================================###
### Include Personal Environment Variables
###===============================================================================================###
[ -f "${HOME}/.bash_environment" ] && . "${HOME}/.bash_environment"
