###===============================================================================================###
###  Misc utilities
###  File: .bashrc.d/03-functions-utility.sh
### 
###  Modified for Apple Silicon Mac OS
###
###  Purpose: 
###  Everything else that doesn't fit in the other categories, like 
###  custom functions and aliases
###
###  Created by Karl Vietmeier
###  License: Apache 2.0
###===============================================================================================###


#===============================================================================#
# Function: print_tfvars
# Purpose: Print the current values of Terraform variables related to VAST Data
#===============================================================================#
print_tfvars() {
    echo "Printing Terraform variable values:"
    echo "-----------------------------------"
    # Native Provider Fallbacks (Automatically read by the vastdata provider)
    echo "VASTDATA_HOST: ${VASTDATA_HOST}"
    echo "VASTDATA_PORT: ${VASTDATA_PORT}"
    echo "VASTDATA_TENANT: ${VASTDATA_TENANT}"
    echo "-----------------------------------"
    # Terraform Input Variable Overrides (Mapped via TF_VAR_ prefix)
    echo "TF_VAR_vast_username: ${TF_VAR_vast_username}"
    echo "TF_VAR_vast_password: ${TF_VAR_vast_password}"
    echo "TF_VAR_vast_skip_ssl_verify: ${TF_VAR_vast_skip_ssl_verify}"
    echo "TF_VAR_vast_version_validation_mode: ${TF_VAR_vast_version_validation_mode}"
    echo "TF_VAR_vast_api_token: ${TF_VAR_vast_api_token}"
    echo "-----------------------------------"
}   


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
        echo "asciinema not found. Please install it first."
        return 1
    fi

    # Quoted the variable to prevent errors if the path contains spaces
    mkdir -p "$CONSOLE_LOGS_DIR"  
    TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
    
    # Use hostname -s to prevent macOS from appending local DNS suffixes to your files
    LOGFILE="${CONSOLE_LOGS_DIR}/$(hostname -s)_${USER}_${TIMESTAMP}.cast"

    echo "📄 Logging session to: $LOGFILE"
    echo "💡 Press Ctrl-D or type 'exit' to stop logging"

    asciinema rec "$LOGFILE"
}

logsoff() {
    echo "🟢 Press Ctrl-D in the asciinema session to stop logging."
}

# List all asciinema logs in CONSOLE_LOGS_DIR
listlogs() {
    echo "📄 Logs in $CONSOLE_LOGS_DIR:"
    ls -1t "$CONSOLE_LOGS_DIR"
}


# ==============================================================================
# Personal Edge Workspace Isolation
# ==============================================================================
personal_edge_workspace() {
    local personal_profile_dir="${HOME}/.config/personal_edge_profile"
    
    if [[ ! -d "${personal_profile_dir}" ]]; then
        echo "Initializing air-gapped personal environment..."
        mkdir -p "${personal_profile_dir}"
    fi

    # Launch Edge with a physically isolated user-data directory.
    # --process-per-site optimizes footprint for the 24GB M5 unified memory.
    open -na "Microsoft Edge" --args \
        --user-data-dir="${personal_profile_dir}" \
        --process-per-site \
        --no-first-run
}

# ==============================================================================
# Google Chrome
# ==============================================================================
personal_chrome_workspace() {
    local chrome_profile_dir="${HOME}/.config/personal_chrome_profile"
    
    if [[ ! -d "${chrome_profile_dir}" ]]; then
        echo "Initializing air-gapped personal Chrome environment..."
        mkdir -p "${chrome_profile_dir}"
    fi

    # Launch Chrome with a physically isolated user-data directory.
    # --process-per-site optimizes footprint for the 24GB M5 unified memory.
    open -na "Google Chrome" --args \
        --user-data-dir="${chrome_profile_dir}" \
        --process-per-site \
        --no-first-run
}

# ==============================================================================
# Ephemeral Browser Testing Workspaces (Automated Teardown)
#
# To execute a single-use testing browser on macOS, construct a 
# temporary directory (mktemp) at runtime, point Chromium directly to that path 
# as its isolate --user-data-dir, and bind a Bash trap or blocking wait loop 
# that nukes the directory the instant the browser process terminates.
# ==============================================================================

# Generic throwaway Google Chrome instance
test_workspace_chrome() {
    local target_url="${1:-about:blank}"
    local tmp_dir

    # Create a unique temporary directory in RAM/tmp space
    tmp_dir=$(mktemp -d -t "chrome_ephemeral_XXXXXX") || {
        echo "[-] Failed to allocate temporary profile directory." >&2
        return 1
    }

    echo "[+] Initializing pristine, throwaway Chrome test environment..."
    echo "[+] Profile Path: ${tmp_dir}"

    # Execute Chrome binary directly (blocking call) to bind lifecycle to shell
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
        --user-data-dir="${tmp_dir}" \
        --no-first-run \
        --no-default-browser-check \
        --disable-sync \
        --process-per-site \
        "${target_url}" &>/dev/null

    # Atomic purge upon browser termination
    echo "[+] Terminating session and nuking temporary state..."
    rm -rf "${tmp_dir}"
    echo "[+] Cleanup complete. Zero-drift maintained."
}

# Generic throwaway Microsoft Edge instance with deterministic window geometry
test_workspace_edge() {
    local target_url="${1:-about:blank}"
    local tmp_dir

    tmp_dir=$(mktemp -d -t "edge_ephemeral_XXXXXX") || {
        echo "[-] Failed to allocate temporary profile directory." >&2
        return 1
    }

    echo "[+] Initializing pristine, throwaway Edge test environment..."
    echo "[+] Profile Path: ${tmp_dir}"

    # Execute Edge binary directly to preserve shell process binding.
    # Appends explicit 1195x1113 geometry and M5 memory-conservation flags.
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
        --user-data-dir="${tmp_dir}" \
        --window-size=1195,1113 \
        --no-first-run \
        --no-default-browser-check \
        --disable-sync \
        --process-per-site \
        --enable-features=high-efficiency-mode \
        "${target_url}" &>/dev/null

    echo "[+] Terminating session and nuking temporary state..."
    rm -rf "${tmp_dir}"
    echo "[+] Cleanup complete. Zero-drift maintained."
}