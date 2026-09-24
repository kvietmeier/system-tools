###===============================================================================================###
#    Misc utilities
#    File: .bashrc.d/03-functions-utility.sh
#     Purpose: 
#     Everything else that doesn't fit in the other categories, like custom functions and aliases
#    Created by Karl Vietmeier
#    License: Apache 2.0
###===============================================================================================###


#==============================================#
# Function: GetMyIP
# Purpose: Get public IP from ipinfo.io and export it
#==============================================#
get_my_ip() {
    # Attempt to get public IP from ipinfo.io
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        response=$(curl -s https://ipinfo.io)
        my_ip=$(echo "$response" | jq -r '.ip // empty')

        if [ -n "$my_ip" ]; then
            echo
            echo "Current Router/VPN IP: $my_ip"
            echo
            export MYIP="$my_ip"
        else
            echo "Unable to retrieve IP from ipinfo.io"
            return 1
        fi
    else
        echo "Error: curl and jq are required to run GetMyIP"
        return 2
    fi
}


# logson / logsoff
# ----------------
# Uses asciinema which must be installed separately, to record terminal sessions in a shareable format.
# https://docs.asciinema.org/
# logson starts an asciinema session, recording all commands and output in real time.
# Logs are saved in SESSION_LOGS_DIR with a unique filename: hostname_user_timestamp.cast.
# logsoff reminds you to stop logging by pressing Ctrl-D or typing exit.
logson() {

    # Check if asciinema is installed
    if ! command -v asciinema &> /dev/null; then
        echo "❌ asciinema not found. Please install it first."
        return 1
    fi

    mkdir -p $CONSOLE_LOGS_DIR  # Ensure log directory exists
    TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
    LOGFILE="${CONSOLE_LOGS_DIR}/$(hostname)_${USER}_${TIMESTAMP}.cast"

    echo "📄 Logging session to: $LOGFILE"
    echo "💡 Press Ctrl-D or type 'exit' to stop logging"

    asciinema rec $LOGFILE
}

logsoff() {
    echo "🟢 Press Ctrl-D in the asciinema session to stop logging."
}

# List all asciinema logs in CONSOLE_LOGS_DIR
listlogs() {
    echo "📄 Logs in $CONSOLE_LOGS_DIR:"
    ls -1t "$CONSOLE_LOGS_DIR"
}


###===============================================================================================###
#    vastcloud
###===============================================================================================###

### Using staging
export VASTC_GCP=staging-gcp-vast-on-cloud-ctx
export VASTC_AWS=staging-aws-600627351840-ctx

vc_use() {
    case "$1" in
        gcp)
            export VASTC_CONTEXT="$VASTC_GCP"
            ;;
        aws)
            export VASTC_CONTEXT="$VASTC_AWS"
            ;;
        *)
            echo "Usage: vast_use {gcp|aws}"
            return 1
            ;;
    esac

    vastcloud config use-context "$VASTC_CONTEXT"
    echo "🔹 Active context: $VASTC_CONTEXT"
}


vast_status() {
    echo "=============================="
    echo "VASTCloud Status"
    echo "=============================="

    echo ""
    echo "🔹 Context:"
    vastcloud config current-context 2>/dev/null || echo "  (no context available)"

    echo ""
    echo "🔹 Auth Status:"
    vastcloud auth status 2>/dev/null || echo "  (not authenticated)"

    echo ""
    echo "=============================="
}


alias vcls='vastcloud cluster list'
alias vcauth='vastcloud auth status'
alias vcuse='vc_use'
alias vcstatus='vast_status'


#==============================================#
# Function: check_cloud_auth
# Purpose: Quick identity check across Polaris/vastcloud + Azure/GCP/AWS CLIs
#==============================================#
check_cloud_auth() {
    local GREEN='\033[0;32m'
    local BLUE='\033[0;34m'
    local ORANGE='\033[0;33m'
    local RED='\033[0;31m'
    local NC='\033[0m'

    echo -e "${BLUE}--- Cloud Identity & Polaris Status ---${NC}"

    echo -ne "Polaris:  "
    if command -v vastcloud &> /dev/null; then
        local VC_CTX VC_AUTH VC_USER
        VC_CTX=$(vastcloud config current-context 2>/dev/null)
        VC_AUTH=$(vastcloud auth status 2>/dev/null | head -1)
        if [[ "$VC_AUTH" == *"Authenticated as"* ]]; then
            VC_USER=$(echo "$VC_AUTH" | sed -E 's/.*Authenticated as[[:space:]]+//')
            echo -e "${GREEN}${VC_USER}${NC} (ctx: ${VC_CTX:-none})"
        else
            echo -e "${ORANGE}Not logged in (vastcloud login)${NC}"
        fi
    else
        echo -e "${RED}CLI not found${NC}"
    fi

    echo -ne "Azure:    "
    if command -v az &> /dev/null; then
        local AZ_USER
        AZ_USER=$(az account show --query 'user.name' -o tsv 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${AZ_USER}${NC}"
        else
            echo -e "${ORANGE}Not logged in (az login)${NC}"
        fi
    else
        echo -e "${RED}CLI not found${NC}"
    fi

    echo -ne "GCP:      "
    if command -v gcloud &> /dev/null; then
        local GCP_USER GCP_PROJ
        GCP_USER=$(gcloud config get-value account 2>/dev/null)
        GCP_PROJ=$(gcloud config get-value project 2>/dev/null)
        if [ -n "$GCP_USER" ]; then
            echo -e "${GREEN}${GCP_USER}${NC} (Proj: ${GCP_PROJ})"
        else
            echo -e "${ORANGE}Not logged in (gcloud auth login)${NC}"
        fi
    else
        echo -e "${RED}CLI not found${NC}"
    fi

    echo -ne "AWS:      "
    if command -v aws &> /dev/null; then
        local AWS_USER
        AWS_USER=$(aws sts get-caller-identity --query 'Arn' --output tsv --cli-connect-timeout 2 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${AWS_USER}${NC}"
        else
            echo -e "${ORANGE}No valid session (aws sso login)${NC}"
        fi
    else
        echo -e "${RED}CLI not found${NC}"
    fi

    echo -e "${BLUE}------------------------------------${NC}"
}

alias cloudauth='check_cloud_auth'