###############################################################################
### GCP Authentication and Utilities
### File: .bashrc.d/11-gcp-utilities.sh
### Purpose: 
###   GCP utility functions for resource management
###   Assumes environment variables are set in ~/.bash_environment.sh
###
### Created by Karl Vietmeier
### License: Apache 2.0
###############################################################################

# ====================================================================================
#                      GCP Resource Management Functions                             #
# ====================================================================================


# ====================================================================================
# gcp_get_orphaned_routes
# Usage: gcp_get_orphaned_routes
# Returns names of GCP routes that are not associated with any next hop
# ====================================================================================
gcp_get_orphaned_routes() {
    local PROJECT_ID
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

    echo "[+] Scanning project [$PROJECT_ID] for orphaned or stale default network routes..."

    # 1. Fetch all custom-allocated default dynamic/static routes cleanly.
    # 2. Filter out systemic local infrastructure rules (like default-route-allowed).
    # 3. Use an internal check to surface only entries that return empty next-hop definitions.
    gcloud compute routes list \
        --filter="name:default-route-r-* AND NOT name:default-route-allowed*" \
        --format="json" | jq -r '
            .[] | 
            select(
                (.nextHopGateway == null) and 
                (.nextHopIp == null) and 
                (.nextHopInstance == null) and 
                (.nextHopIlb == null) and 
                (.nextHopVpnTunnel == null) and 
                (.nextHopPeering == null) and
                (.nextHopNetwork == null)
            ) | .name'
}


# ====================================================================================
# gcp_get_orphaned_routes_core
# Usage: gcp_get_orphaned_routes_core [vpc_name]
# ====================================================================================
gcp_get_orphaned_routes_core() {
    local VPC_NAME="${1:-${DEFAULT_VPC_NAME:-}}"
    
    if [[ -z "$VPC_NAME" ]]; then
        echo "[-] Error: Please specify a VPC name. Usage: gcp_get_orphaned_routes_core <vpc_name>" >&2
        return 1
    fi

    local PROJECT_ID
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

    echo "[+] Scanning VPC [$VPC_NAME] in project [$PROJECT_ID] for orphaned routes..."

    gcloud compute routes list \
        --filter="network:($VPC_NAME) AND name:default-route-r-* AND NOT name:default-route-allowed*" \
        --format="json" | jq -r '
            .[] | 
            select(
                (.nextHopGateway == null) and 
                (.nextHopIp == null) and 
                (.nextHopInstance == null) and 
                (.nextHopIlb == null) and 
                (.nextHopVpnTunnel == null) and 
                (.nextHopPeering == null) and
                (.nextHopNetwork == null)
            ) | .name'
}

# ====================================================================================
# Network Infrastructure Discovery
# ====================================================================================

# List all subnets with CIDR architecture and Private Google Access (PGA) status
gcp_list_subnets() {
    echo "[+] Fetching project subnets and routing topology..."
    gcloud compute networks subnets list \
        --format="table(name, region.scope():label=REGION, network.basename():label=VPC, ipCidrRange:label=CIDR_RANGE, privateIpGoogleAccess:label=PGA_ENABLED)"
}

# List all internal, private static IP allocations
gcp_list_private_ips() {
    echo "[+] Fetching internal allocated IP addresses..."
    gcloud compute addresses list \
        --filter="addressType=INTERNAL" \
        --format="table(name, address:label=IP_ADDRESS, region.scope():label=REGION, status, purpose)"
}

# ====================================================================================
# Compute Engine Instance Discovery
# ====================================================================================

# List all VM instances with consolidated network and state metadata
gcp_list_instances() {
    echo "[+] Fetching dynamic VM matrix..."
    gcloud compute instances list \
        --format="table(name, status, networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP, networkInterfaces[0].networkIP:label=INTERNAL_IP, zone.scope():label=ZONE)"
}

# List allocated private IPs mapped exclusively to hostnames
gcp_list_vm_ips() {
   echo "[+] Extracting private compute interface routes..."
   gcloud compute instances list \
        --format="table(name, zone.scope():label=ZONE, networkInterfaces[0].networkIP:label=PRIVATE_IP)"
}

# ====================================================================================
# gcp_manage_client_vms
# Usage: gcp_manage_client_vms <start|stop|resume|list> [count] [type: lab|gateway]
#        gcp_manage_client_vms <start|stop|resume|list> [type: lab|gateway]
# ====================================================================================
# Function to safely manage batches of Google Cloud VM instances in parallel.
# - Action: "start", "stop", "resume", or "list"
# - Count: Optional integer to limit the number of VMs processed (default: all)
# - Type: Optional target selection, either "lab" or "gateway" (default: lab)
#
# Operational Highlights:
#   - Auto-shifts positional arguments if count is omitted (e.g., 'list gateway').
#   - Queries global runtime matrices in 1 single, efficient API call.
#   - Minimizes API mutations by skipping VMs already in the desired target state.
#   - Executes gcloud state changes in async parallel background threads.
#   - Bypasses interactive CLI confirmations with native tracking hooks.
# ====================================================================================
gcp_manage_client_vms() {
    local ACTION=$1
    local COUNT=$2
    local TYPE=$3

    # Smart Auto-Shift: If the 2nd argument is an explicit asset type type instead of a number
    if [[ "$COUNT" == "gateway" || "$COUNT" == "lab" ]]; then
        TYPE=$COUNT
        COUNT=0
    fi
    
    # Enforce strict default fallbacks
    COUNT=${COUNT:-0}
    TYPE=${TYPE:-lab}

    if [[ "$ACTION" != "start" && "$ACTION" != "stop" && "$ACTION" != "resume" && "$ACTION" != "list" ]]; then
        echo "Error: Action must be start, stop, resume, or list."
        echo "Usage: gcp_manage_client_vms [action] [optional_count] [optional_type: lab|gateway]"
        return 1
    fi

    # 1. Define Managed Resource Footprints
    local ALL_VMS=()
    local FILTER_STRING=""

    if [[ "$TYPE" == "gateway" ]]; then
        FILTER_STRING="name:voc-gateway*"
        ALL_VMS=("voc-gateway" "voc-gateway2" "voc-gateway3" "voc-gateway4" "voc-gateway5" \
                 "voc-gateway6" "voc-gateway7" "voc-gateway8" "voc-gateway9" "voc-gateway10" \
                 "voc-gateway11" "voc-gateway12" "voc-gateway13" "voc-gateway14" "voc-gateway15" \
                 "voc-gateway16" "voc-gateway17" "voc-gateway18" "voc-gateway19" "voc-gateway20")
    else
        FILTER_STRING="name:labgroup*"
        ALL_VMS=("labgroup01" "labgroup02" "labgroup03" "labgroup04" "labgroup05" \
                 "labgroup06" "labgroup07" "labgroup08" "labgroup09" "labgroup10" \
                 "labgroup11" "labgroup12" "labgroup13" "labgroup14" "labgroup15" \
                 "labgroup16" "labgroup17" "labgroup18" "labgroup19" "labgroup20")
    fi

    # Slice array footprint if a count ceiling is explicitly specified
    if [[ $COUNT -gt 0 && $COUNT -le ${#ALL_VMS[@]} ]]; then
        ALL_VMS=("${ALL_VMS[@]:0:$COUNT}")
    fi

    echo "Fetching VM status from Compute Engine API..."
    
    # Dynamic Batch Query based on targeted asset type
    local STATE_MATRIX
    STATE_MATRIX=$(gcloud compute instances list \
        --filter="$FILTER_STRING" \
        --format="value(name,status,zone.scope())")

    declare -A VM_ZONES
    declare -A VM_STATUSES
    declare -A JOB_PIDS
    declare -A FINAL_OUTCOMES

    # Parse state matrix into memory mapping arrays
    while read -r name status zone; do
        if [[ -n "$name" ]]; then
            VM_STATUSES["$name"]="$status"
            VM_ZONES["$name"]="$zone"
        fi
    done <<< "$STATE_MATRIX"

    # Handle Read-Only List Path
    if [[ "$ACTION" == "list" ]]; then
        echo ""
        echo "========================================================"
        echo "          CURRENT RESOURCE INVENTORY ($TYPE)           "
        echo "========================================================"
        printf "%-15s | %-12s | %-15s\n" "VM NAME" "STATUS" "ZONE"
        echo "--------------------------------------------------------"
        for VM in "${ALL_VMS[@]}"; do
            local TARGET_ZONE="${VM_ZONES[$VM]:-UNKNOWN}"
            local CURRENT_STATUS="${VM_STATUSES[$VM]:-NOT FOUND}"
            printf "%-15s | %-12s | %-15s\n" "$VM" "$CURRENT_STATUS" "$TARGET_ZONE"
        done
        echo "========================================================"
        return 0
    fi

    # Disable job control reporting to keep terminal output clean
    set +m

    for VM in "${ALL_VMS[@]}"; do
        local TARGET_ZONE="${VM_ZONES[$VM]}"
        local CURRENT_STATUS="${VM_STATUSES[$VM]}"

        if [[ -z "$TARGET_ZONE" ]]; then
            echo "[-] Error: Instance $VM not found in active project metadata inventory."
            FINAL_OUTCOMES["$VM"]="Not Found"
            continue
        fi

        # Skip evaluation logic to minimize unnecessary API mutations
        if [[ "$ACTION" == "stop" && ("$CURRENT_STATUS" == "TERMINATED" || "$CURRENT_STATUS" == "STOPPING") ]]; then
            echo "[=] $VM is already $CURRENT_STATUS. Skipping."
            FINAL_OUTCOMES["$VM"]="Skipped (Already Inactive)"
            continue
        elif [[ "$ACTION" == "start" && "$CURRENT_STATUS" == "RUNNING" ]]; then
            echo "[=] $VM is already RUNNING. Skipping."
            FINAL_OUTCOMES["$VM"]="Skipped (Already Running)"
            continue
        fi

        echo "[+] Dispatching $ACTION request for $VM in $TARGET_ZONE..."

        # Async execution block with interactive prompts disabled via --quiet
        if [[ "$ACTION" == "start" && "$CURRENT_STATUS" == "SUSPENDED" ]]; then
            gcloud compute instances resume "$VM" --zone="$TARGET_ZONE" --quiet &>/dev/null &
        else
            gcloud compute instances "$ACTION" "$VM" --zone="$TARGET_ZONE" --quiet &>/dev/null &
        fi
        
        JOB_PIDS["$VM"]=$!
    done

    echo "--------------------------------------------------------"
    echo "Awaiting parallel processing threads to resolve state changes..."
    echo "--------------------------------------------------------"

    # Trap background PIDs directly using your sequential array layout
    for VM in "${ALL_VMS[@]}"; do
        if [[ -n "${JOB_PIDS[$VM]}" ]]; then
            wait "${JOB_PIDS[$VM]}"
            if [[ $? -eq 0 ]]; then
                FINAL_OUTCOMES["$VM"]="Success"
            else
                FINAL_OUTCOMES["$VM"]="Failed"
            fi
        fi
    done

    # Reset standard terminal job tracking behavior
    set -m

    echo ""
    echo "========================================================"
    echo "             VM State Change Summary ($TYPE)             "
    echo "========================================================"
    for VM in "${ALL_VMS[@]}"; do
        printf "Result for %-15s : %s\n" "$VM" "${FINAL_OUTCOMES[$VM]:-Skipped}"
    done
    echo "========================================================"
}


# ====================================================================================
# IAM & Security Auditing
# ====================================================================================

# List IAM custom roles with optional pattern filtering
# Usage: gcp_check_roles [filter_string]
gcp_check_roles() {
    local TARGET_PROJECT
    TARGET_PROJECT=$(gcloud config get-value project 2>/dev/null)
    local ROLE_FILTER="$1"

    if [[ -z "$TARGET_PROJECT" ]]; then
        echo "[-] Error: Active gcloud project context is not set."
        echo "    Run: gcloud config set project <project-id>"
        return 1
    fi

    echo "[+] Auditing custom IAM security definitions in project: [$TARGET_PROJECT]"

    # Use comprehensive matrix formatting to map role status and stage permissions cleanly
    if [[ -n "$ROLE_FILTER" ]]; then
        gcloud iam roles list \
            --project="$TARGET_PROJECT" \
            --filter="name:($ROLE_FILTER) OR title:($ROLE_FILTER)" \
            --format="table(name.basename():label=ROLE_ID, title, stage, description:label=DETAILS)"
    else
        gcloud iam roles list \
            --project="$TARGET_PROJECT" \
            --format="table(name.basename():label=ROLE_ID, title, stage, description:label=DETAILS)"
    fi
}

# ====================================================================================
# Advanced Networking & Allocation Utilities
# ====================================================================================

# Comprehensive reserved IP scanning engine (Global + Zonal/Regional)
# Usage: gcp_get_reserved_ips [--global] [--region=us-central1] [--filter=pattern]
gcp_get_reserved_ips() {
    local TARGET_PROJECT
    TARGET_PROJECT=$(gcloud config get-value project 2>/dev/null)

    if [[ -z "$TARGET_PROJECT" ]]; then
        echo "[-] Error: Active gcloud project context is not set."
        return 1
    fi

    local SCOPE_FLAG="--regions=" # Blanks to fetch all regions by default
    local FILTER_STR=""
    local IS_GLOBAL=false

    # Parse arguments robustly via token iteration to avoid strict positional locks
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --global)
                IS_GLOBAL=true
                shift
                ;;
            --region=*)
                SCOPE_FLAG="--regions=${1#*=}"
                shift
                ;;
            --filter=*)
                FILTER_STR="${1#*=}"
                shift
                ;;
            *)
                # Fallback handler if passed as a legacy raw string
                FILTER_STR="$1"
                shift
                ;;
        esac
    done

    echo "[+] Extracting allocated static routing vectors from: [$TARGET_PROJECT]"

    # Route execution to correct regional/global endpoint configurations
    if [[ "$IS_GLOBAL" == "true" ]]; then
        gcloud compute addresses list \
            --project="$TARGET_PROJECT" \
            --global \
            ${FILTER_STR:+--filter="name~$FILTER_STR"} \
            --format="table(name, address:label=IP_ADDRESS, status, purpose)"
    else
        # If no explicit region parameter was passed, drop the regional constraint to list all regional footprints
        if [[ "$SCOPE_FLAG" == "--regions=" ]]; then
            SCOPE_FLAG=""
        fi
        
        gcloud compute addresses list \
            --project="$TARGET_PROJECT" \
            $SCOPE_FLAG \
            ${FILTER_STR:+--filter="name~$FILTER_STR"} \
            --format="table(name, address:label=IP_ADDRESS, region.scope():label=REGION, status, purpose)"
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

  echo "$ADDRESSES" | xargs -I {} \
    gcloud compute addresses delete {} --region="$REGION" -q

  echo ""
  echo "✅ Cleanup complete."
}


# ====================================================================================
# Optimized Google Cloud Platform Alias Matrix
# ====================================================================================

if command -v gcloud &>/dev/null; then
    # Compute Engine (GCE) Core Metrics
    alias gcpvms='gcp_list_instances'
    alias gcpvmips='gcp_list_vm_ips'
    alias gcplabvms='gcp_manage_client_vms'

    # Cloud Networking (VPC), Routing, & IPS
    alias gcpsubnets='gcp_list_subnets'
    alias gcpips='gcp_get_reserved_ips'          
    alias gcpprivips='gcp_list_private_ips'
    alias gcporphan='gcp_get_orphaned_routes'
    alias gcporphancore='gcp_get_orphaned_routes_core' 
    alias gcpalias='alias | grep gcp'  # List all GCP aliases

    # Placeholder for Cleanup Operations
    # alias gcpcleanips='gcp_remove_ips'          # Uncomment once gcp_remove_ips is implemented
else
    echo "[-] Warning: gcloud binary client not found. GCP shell extensions bypassed."
fi