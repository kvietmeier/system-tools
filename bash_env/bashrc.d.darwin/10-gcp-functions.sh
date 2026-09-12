###############################################################################
### GCP Authentication and Utilities
### File: .bashrc.d/10-gcp-functions.sh
### Purpose: 
###   Simplify GCP service account authentication and deauthentication
###   Assumes environment variables are set in ~/.bash_environment.sh
### Created by Karl Vietmeier
### License: Apache 2.0
###############################################################################

# ====================================================================================
# gcp_authenticate - Fully Aligned GCP CLI & ADC Authentication
# Sourced via environment variables in ~/.bash_environment.sh
# ====================================================================================

gcp_authenticate() {
    # 1. Validate environment inputs
    if [[ -z "${GCP_PROJECT_ID:-}" || -z "${GCP_SA_EMAIL:-}" ]]; then
        echo "[-] Error: GCP_PROJECT_ID or GCP_SA_EMAIL is missing from environment." >&2
        return 1
    fi

    echo "[+] Initializing GCP authentication matrix..."

    # 2. Clear file overrides that bypass ADC lookup
    unset GOOGLE_APPLICATION_CREDENTIALS GCP_DEFAULT_PROJECT

    # 3. Verify primary gcloud human user identity (Required for CLI SA impersonation)
    local ACTIVE_ACCOUNT
    ACTIVE_ACCOUNT=$(gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>/dev/null | head -n 1)

    if [[ -z "$ACTIVE_ACCOUNT" ]]; then
        echo "[!] No active gcloud user account found. Launching user login..."
        if ! gcloud auth login; then
            echo "[-] Error: Interactive user login failed." >&2
            return 1
        fi
        ACTIVE_ACCOUNT=$(gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>/dev/null | head -n 1)
    else
        echo "[+] Found active human identity: [${ACTIVE_ACCOUNT}]."
    fi

    # Explicitly bind the active user account to gcloud config
    gcloud config set account "${ACTIVE_ACCOUNT}" &>/dev/null

    # 4. Check and generate Application Default Credentials (ADC) for Go SDKs & vastcloud
    if ! gcloud auth application-default print-access-token &>/dev/null; then
        echo "[!] ADC token missing or expired. Initializing ADC with SA impersonation..."
        if ! gcloud auth application-default login --impersonate-service-account="${GCP_SA_EMAIL}"; then
            echo "[-] Error: Application Default Credentials initialization failed." >&2
            return 1
        fi
        gcloud auth application-default set-quota-project "${GCP_PROJECT_ID}" &>/dev/null
    else
        echo "[+] Found valid Application Default Credentials (ADC)."
    fi

    # 5. Target project workspace and apply gcloud CLI impersonation
    gcloud config set project "${GCP_PROJECT_ID}" &>/dev/null
    gcloud config set auth/impersonate_service_account "${GCP_SA_EMAIL}" &>/dev/null

    # 6. Synchronize VAST Polaris context if vastcloud binary exists
    if command -v vastcloud >/dev/null 2>&1; then
        local target_ctx="staging-gcp-${GCP_PROJECT_ID}-ctx"
        vastcloud config use-context "$target_ctx" &>/dev/null || true
        export VASTC_CONTEXT="$target_ctx"
        export POLARIS_CONTEXT="$target_ctx"
    fi

    echo "[+] System Identity Matrix: User [${ACTIVE_ACCOUNT}] active, ADC set, project pinned, and impersonation active."

}

# ====================================================================================
# gcp_deauth - Identity Demobilization
# ====================================================================================
gcp_deauth() {
    echo "[!] Demobilizing local Google Cloud authentication matrix..."

    # Unset impersonation first to ensure revocation executes under base identity
    gcloud config unset auth/impersonate_service_account &>/dev/null
    gcloud config unset project &>/dev/null
    
    # Revoke standard CLI and ADC credentials
    gcloud auth application-default revoke --quiet &>/dev/null
    gcloud auth revoke --all --quiet &>/dev/null

    echo "[+] Local auth states purged. Context cleared successfully."
}
# ====================================================================================
# Telemetry, Tokens, & State Auditing
# ====================================================================================

# Print a structured high-density matrix of current authentication profiles
gcp_status() {
    echo "========================================================"
    echo "               GCP AUTHENTICATION STATUS                "
    echo "========================================================"
    
    local ACTIVE_ACCOUNT
    ACTIVE_ACCOUNT=$(gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>/dev/null)
    echo "Active Account : ${ACTIVE_ACCOUNT:-No active account found}"

    local ACTIVE_PROJECT
    ACTIVE_PROJECT=$(gcloud config get-value project 2>/dev/null)
    echo "Target Project : ${ACTIVE_PROJECT:-No project scope set}"
    echo "========================================================"
}

# Get the targeted core active project string
gcp_get_project() {
    local CURRENT_PRJ
    CURRENT_PRJ=$(gcloud config get-value project 2>/dev/null)
    echo "The current active project is: [${CURRENT_PRJ:-NONE}]"
}

# Get the targeted core active identity account string
gcp_get_core_acct() {
    local CURRENT_ACC
    CURRENT_ACC=$(gcloud config get-value account 2>/dev/null)
    echo "Running as: [${CURRENT_ACC:-NONE}]"
}

# Print the dynamic Oauth2 access token string
gcp_get_access_token() {
    local ACCESS_TOKEN
    ACCESS_TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null)
    echo "Current Access Token: ${ACCESS_TOKEN:-TOKEN RESOLUTION FAILED}"
}

# ====================================================================================
# Context & Workspace Named Profile Management
# ====================================================================================

# List all available local gcloud configuration profiles
gcp_configurations() {
    echo "[+] Scanning local gcloud named profile workspaces..."
    gcloud config configurations list
}

# Display the name of the currently active configuration profile workspace
gcp_config_active() {
    local ACTIVE_CONF
    ACTIVE_CONF=$(gcloud config configurations list --filter="is_active=true" --format="value(name)" 2>/dev/null)
    echo "Current active gcloud configuration: [${ACTIVE_CONF:-default}]"
}

# Set the active gcloud configuration workspace cleanly
# Usage: gcp_set_config <configuration-name>
gcp_set_config() {
    local CONFIG_NAME=$1
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "[-] Error: Missing configuration name."
        echo "    Usage: gcp_set_config <configuration-name>"
        return 1
    fi

    echo "[+] Switching active gcloud workspace configuration profile to: [$CONFIG_NAME]"
    
    local ATTEMPT_OUT
    ATTEMPT_OUT=$(gcloud config configurations activate "$CONFIG_NAME" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "[-] Error: Failed to activate configuration workspace."
        echo "    API Details: $ATTEMPT_OUT"
        return 1
    fi

    echo "[+] Active workspace context locked to: [$CONFIG_NAME]"
}


# ====================================================================================
# Optimized Google Cloud Platform Alias Matrix
# ====================================================================================

if command -v gcloud &>/dev/null; then
    # Identity, Authentication, & Access Management (IAM)
    alias gcplogin='gcp_authenticate'
    alias gcplogout='gcp_deauth'
    alias gcpuser='gcp_get_core_acct'
    alias gcptoken='gcp_get_access_token'
    alias gcproles='gcp_check_roles'

    # Workspace Context & Named Profiles
    alias gcproj='gcp_get_project'
    alias gcpconfigs='gcp_configurations'
    alias gcpconfig='gcp_config_active'
    alias gcpconfigset='gcp_set_config'

    # Placeholder for Cleanup Operations
    # alias gcpcleanips='gcp_remove_ips'          # Uncomment once gcp_remove_ips is implemented
else
    echo "[-] Warning: gcloud binary client not found. GCP shell extensions bypassed."
fi