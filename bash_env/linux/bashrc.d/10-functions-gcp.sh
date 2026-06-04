###############################################################################
### GCP Authentication and Utilities
### File: .bashrc.d/10-functions-gcp.sh
### Purpose: 
###   Simplify GCP service account authentication and deauthentication
### Created by Karl Vietmeier
### License: Apache 2.0
###############################################################################


###--- Authenticate to GCP using service account credentials
###--- Assumes environment variables are set in .bash_environment or manually:

gcp_auth() {
    # Validate environment variables and credentials file
    {
        [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ] || {
            echo "Missing or invalid credentials file: \$GOOGLE_APPLICATION_CREDENTIALS is not set or file does not exist"
            return 1
        }

        [ -n "$GCP_DEFAULT_PROJECT" ] || {
            echo "Missing GCP project ID. Set GCP_DEFAULT_PROJECT environment variable."
            return 1
        }
    }

    echo "Using credentials file: $GOOGLE_APPLICATION_CREDENTIALS"

    # Activate service account and set project
    gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS" > /dev/null 2>&1 || {
        echo "Failed to activate service account."
        return 1
    }

    gcloud config set project "$GCP_DEFAULT_PROJECT" > /dev/null 2>&1 || {
        echo "Failed to set GCP project: $GCP_DEFAULT_PROJECT"
        return 1
    }

    # Validate Application Default Credentials
    gcloud auth application-default print-access-token > /dev/null 2>&1 || {
        echo "Failed to retrieve access token."
        return 1
    }

    echo "Service account activated, project set, and ADC validated."
}

###--- Deauthenticate from GCP
###--- Deauthenticate from GCP
gcp_deauth() {
    echo "Deauthenticating from GCP..."

    # Revoke application default credentials (ADC)
    gcloud auth application-default revoke --quiet > /dev/null 2>&1

    # Revoke all gcloud accounts
    gcloud auth revoke --all --quiet > /dev/null 2>&1

    # Unset active account and project
    gcloud config unset account > /dev/null 2>&1
    gcloud config unset project > /dev/null 2>&1

    # Remove environment variables (current shell only)
    unset GOOGLE_APPLICATION_CREDENTIALS
    unset GCP_DEFAULT_PROJECT

    echo "GCP authentication and local configuration cleared."
}

###--- Check GCP Authentication Status - ported from PowerShell Get-GcpAuthStatus
gcp_status() {
    echo "GCP Authentication Status:"         
    gcloud auth list --filter=status:ACTIVE --format="value(account)" || echo "No active account"
    echo "Current GCP Project:"
    gcloud config get-value project || echo "No project set"
}

# Get the current active Google Cloud project
gcp_get_project() {
    CurrentProject=$(gcloud info --format="value(config.project)")
    echo "The current active project is: $CurrentProject"
}

# Get the current core Google Cloud account
gcp_get_core_acct() {
    CoreAccount=$(gcloud config list account --format="value(core.account)")
    echo "The current core account is: $CoreAccount"
}

# Get the Google Cloud application default access token
gcp_get_access_token() {
    GCPAccessToken=$(gcloud auth application-default print-access-token)
    echo "Current Access Token: $GCPAccessToken"
}

# Returns names of GCP routes that are not associated with any next hop
gcp_get_orphaned_routes() {
    gcloud compute routes list \
        --filter="NOT (nextHopGateway:* OR nextHopIp:* OR nextHopInstance:* OR nextHopIlb:* OR nextHopVpnTunnel:* OR nextHopPeering:*)" \
        --format="value(name)"
}

# Returns orphaned routes in a specific VPC (example: karlv-corevpc)
gcp_get_orphaned_routes_core() {
    gcloud compute routes list \
        --filter="network:karlv-corevpc AND NOT (nextHopGateway:* OR nextHopIp:* OR nextHopInstance:* OR nextHopIlb:* OR nextHopVpnTunnel:* OR nextHopPeering:*)" \
        --format="value(name)"
}

# List all subnets
gcp_list_subnets() {
    gcloud compute networks subnets list
}

# List all VM instances with useful info
gcp_list_instances() {
    gcloud compute instances list \
        --format="table(name, status, networkInterfaces[0].accessConfigs[0].natIP, networkInterfaces[0].networkIP, zone)"
}

# List allocated private IPs
gcp_list_vm_ips() {
   gcloud compute instances list --format='table(name, zone, networkInterfaces[0].networkIP:label=PRIVATE_IP)'
}

gcp_list_private_ips() {
   gcloud compute addresses list --filter="addressType=INTERNAL" --format="table(name, address, region, status, purpose)"
}



# ====================================================================================
# GCPManageClientVMs
# Usage: GCPManageClientVMs <start|stop|resume> [count]
# ====================================================================================
# Function to start or stop a list of Google Cloud VM instances.
# - Action: "start" or "stop"
# - Count: optional, limits how many VMs to process (default: all)
#
# The function:
#   - Skips VMs already in the desired state (RUNNING/TERMINATED/SUSPENDED).
#   - Executes gcloud operations in parallel for speed.
#   - Summarizes results at the end.
# ====================================================================================

gcp_manage_client_vms() {
    local ACTION=$1
    local COUNT=${2:-0}

    local VMS=("client01" "client02" "client03" "client04" "client05" \
               "client06" "client07" "client08" "client09" "client10" "client11")

    # Trim the list if COUNT is specified
    if [[ $COUNT -gt 0 ]]; then
        VMS=("${VMS[@]:0:$COUNT}")
    fi

    declare -A JOB_PIDS
    declare -A JOB_RESULTS

    # Disable job control messages
    set +m

    for VM in "${VMS[@]}"; do
        ZONE=$(gcloud compute instances list --filter="name=$VM" --format="value(zone)" | head -n1)
        if [[ -z "$ZONE" ]]; then
            echo "Error: Could not determine zone for $VM"
            JOB_RESULTS["$VM"]="Failed"
            continue
        fi

        STATUS=$(gcloud compute instances describe "$VM" --zone "$ZONE" --format="get(status)")

        if [[ "$ACTION" == "start" && "$STATUS" == "RUNNING" ]]; then
            echo "$VM is already RUNNING, skipping."
            JOB_RESULTS["$VM"]="Skipped"
            continue
        elif [[ "$ACTION" == "stop" && "$STATUS" == "TERMINATED" ]]; then
            echo "$VM is already TERMINATED, skipping."
            JOB_RESULTS["$VM"]="Skipped"
            continue
        fi

        echo "Queuing $ACTION for $VM (current status: $STATUS)..."

        # Run each gcloud command in a background subshell, redirecting all output to /dev/null
        (
            if [[ "$ACTION" == "start" && "$STATUS" == "SUSPENDED" ]]; then
                gcloud compute instances resume "$VM" --zone "$ZONE" &>/dev/null
            else
                gcloud compute instances "$ACTION" "$VM" --zone "$ZONE" &>/dev/null
            fi
        ) &
        JOB_PIDS["$VM"]=$!
    done

    # Wait for all background jobs
    for VM in "${!JOB_PIDS[@]}"; do
        wait "${JOB_PIDS[$VM]}"
        JOB_RESULTS["$VM"]="Completed"
    done

    echo ""
    for VM in "${VMS[@]}"; do
        echo "Result for $VM: ${JOB_RESULTS[$VM]:-Skipped}"
    done

    echo "All requested VM operations finished."
}

gcp_check_roles() {
  local PROJECT_ID
  PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
  
  local FILTER="$1"

  if [[ -z "$PROJECT_ID" ]]; then
    echo "Usage: check_roles <project-id> [filter]"
    return 1
  fi

  echo "🔎 Checking IAM custom roles in project: $PROJECT_ID"
  echo

  if [[ -n "$FILTER" ]]; then
    gcloud iam roles list \
      --project="$PROJECT_ID" \
      --filter="name:$FILTER"
  else
    gcloud iam roles list \
      --project="$PROJECT_ID"
  fi
}

get_reserved_ips() {
  local PROJECT_ID
  PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

  if [[ -z "$PROJECT_ID" ]]; then
    echo "❌ No active gcloud project set."
    echo "Run: gcloud config set project <project-id>"
    return 1
  fi

  local FILTER="$1"
  local REGION="$2"
  local GLOBAL="$3"

  echo "🌐 Checking provisioned addresses in project: $PROJECT_ID"
  echo

  if [[ "$GLOBAL" == "global" ]]; then
    gcloud compute addresses list \
      --project="$PROJECT_ID" \
      --global \
      ${FILTER:+--filter="name~$FILTER"}
  else
    gcloud compute addresses list \
      --project="$PROJECT_ID" \
      ${REGION:+--regions="$REGION"} \
      ${FILTER:+--filter="name~$FILTER"}
  fi
}

# Deletes RESERVED addresses matching a name filter in a specified region
gcp_remove_ips() {
  local FILTER="$1"
  local REGION="$2"

  if [[ -z "$FILTER" || -z "$REGION" ]]; then
    echo "Usage: gcleanips <name-filter> <region>"
    echo "Example: gcleanips polaris us-central1"
    return 1
  fi

  echo ""
  echo "🔍 Searching for RESERVED addresses matching '$FILTER' in $REGION..."
  echo ""

  ADDRESSES=$(gcloud compute addresses list \
    --filter="name~$FILTER AND region:($REGION) AND status=RESERVED" \
    --format="value(name)")

  if [[ -z "$ADDRESSES" ]]; then
    echo "✅ No matching RESERVED addresses found."
    return 0
  fi

  echo "The following addresses will be deleted:"
  echo "$ADDRESSES"
  echo ""

  read -p "Proceed? (y/N): " CONFIRM
  if [[ "$CONFIRM" != "y" ]]; then
    echo "Aborted."
    return 1
  fi

  echo ""
  echo "🗑 Deleting..."
  echo ""

  echo "$ADDRESSES" | xargs -r -I {} \
    gcloud compute addresses delete {} --region="$REGION" -q

  echo ""
  echo "✅ Cleanup complete."
}


###=================================================================================================###
###  Aliases
###=================================================================================================###

# --- GCP aliases if gcloud exists
if command -v gcloud >/dev/null 2>&1; then
    alias gcpvms=gcp_list_instances
    alias gcpsubnets=gcp_list_subnets
    alias gcporphanroutes=gcp_get_orphaned_routes_core
    alias gcporphan=gcp_get_orphaned_routes
    alias gcptoken=gcp_get_access_token
    alias gcpuser=gcp_get_core_acct
    alias gcproj=gcp_get_project
    alias gcplogin=gcp_auth
    alias gcplogout=gcp_deauth
    alias gcpvmips=gcp_list_vm_ips
    alias gcpallips=gcp_list_private_ips
    alias gcloud="$GCLOUD_CMD"
fi