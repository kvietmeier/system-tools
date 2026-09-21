###############################################################################
### Azure functions
### File: .bashrc.d/12-functions-azure.sh
### Purpose: 
###  Simplify Azure authentication and related tasks
### Created by Karl Vietmeier
### License: Apache 2.0
###############################################################################

###############################################################################
### Helper: Azure auth status (alias: azauth / azureauth / azstatus)
### Requires intentional azlogin this shell (AZURE_LAB_AUTH=1) — leftover
### ~/.azure SP tokens alone do NOT count as logged in (same as gcp/aws habit).
### Also requires CLI subscription == AZURE_SUBSCRIPTION_ID when that is set.
###############################################################################
az_auth_status() {
    local line_mode=0
    [[ "${1:-}" == "--line" ]] && line_mode=1

    local GREEN='\033[0;32m' ORANGE='\033[0;33m' RED='\033[0;31m' NC='\033[0m'

    if ! command -v az &>/dev/null; then
        if [[ $line_mode -eq 1 ]]; then
            echo -e "Azure:    ${RED}CLI not found${NC}"
        else
            echo "Azure: az CLI not found"
        fi
        return 1
    fi

    local user user_type sub_id sub_name expected
    expected="${AZURE_SUBSCRIPTION_ID:-}"
    user=$(az account show --query 'user.name' -o tsv 2>/dev/null)
    user_type=$(az account show --query 'user.type' -o tsv 2>/dev/null)
    sub_id=$(az account show --query 'id' -o tsv 2>/dev/null)
    sub_name=$(az account show --query 'name' -o tsv 2>/dev/null)

    local state="none"
    # none | stale | mismatch | ok
    # AZURE_LAB_AUTH is set only by azlogin in this shell; cleared by azlogout.
    if [[ "${AZURE_LAB_AUTH:-0}" != "1" ]]; then
        if [[ -n "$user" ]]; then
            state="stale"
        else
            state="none"
        fi
    elif [[ -z "$user" || -z "$sub_id" ]]; then
        state="none"
    elif [[ -n "$expected" && "$sub_id" != "$expected" ]]; then
        state="mismatch"
    else
        state="ok"
    fi

    if [[ $line_mode -eq 1 ]]; then
        echo -ne "Azure:    "
        case "$state" in
            ok)
                echo -e "${GREEN}${user}${NC} (${sub_name:-$sub_id})"
                ;;
            stale)
                echo -e "${ORANGE}Stale token — run azlogin (or azlogout)${NC}"
                ;;
            mismatch)
                echo -e "${ORANGE}Wrong subscription — run azlogin${NC}"
                ;;
            *)
                echo -e "${ORANGE}Not logged in (azlogin)${NC}"
                ;;
        esac
        [[ "$state" == "ok" ]] && return 0 || return 1
    fi

    echo "========================================================"
    echo "              AZURE AUTHENTICATION STATUS               "
    echo "========================================================"
    case "$state" in
        ok)
            echo -e "Status:       ${GREEN}authenticated (azlogin this shell)${NC}"
            echo "Identity:     $user (${user_type:-unknown})"
            echo "Subscription: ${sub_name:-unknown} ($sub_id)"
            echo "Tenant:       ${AZURE_TENANT_DOMAIN:-unknown}"
            ;;
        stale)
            echo -e "Status:       ${ORANGE}stale ~/.azure token — not an intentional lab session${NC}"
            echo "Identity:     $user (${user_type:-unknown})"
            echo "CLI sub:      ${sub_name:-unknown} ($sub_id)"
            echo "Fix:          azlogout && azlogin"
            ;;
        mismatch)
            echo -e "Status:       ${ORANGE}misaligned — wrong subscription${NC}"
            echo "Identity:     $user (${user_type:-unknown})"
            echo "CLI sub:      ${sub_name:-unknown} ($sub_id)"
            echo "Expected:     ${AZURE_SUBSCRIPTION_NAME:-unknown} ($expected)"
            echo "Fix:          azlogin"
            ;;
        *)
            echo -e "Status:       ${ORANGE}not logged in — run azlogin${NC}"
            if [[ -n "$expected" ]]; then
                echo "Expected sub: ${AZURE_SUBSCRIPTION_NAME:-unknown} ($expected)"
            fi
            ;;
    esac
    echo "========================================================"
    [[ "$state" == "ok" ]] && return 0 || return 1
}

###############################################################################
### Helper function: Check current Azure CLI context
###############################################################################
azcontext() {
    az_auth_status
}


###############################################################################
### Function: Login to Azure with a Service Principal
###############################################################################
azlogin() {
    if [ -z "$AZURE_CLIENT_ID" ] || [ -z "$AZURE_CLIENT_SECRET" ] || \
       [ -z "$AZURE_TENANT_ID" ] || [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
        echo "Missing required variables for Azure CLI Service Principal login."
        echo "Ensure AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID, and AZURE_SUBSCRIPTION_ID are set."
        return 1
    fi

    echo ""
    echo "Authenticating to Azure Subscription: $AZURE_SUBSCRIPTION_ID"
    echo ""

    if ! az login \
        --service-principal \
        --username "$AZURE_CLIENT_ID" \
        --password "$AZURE_CLIENT_SECRET" \
        --tenant "$AZURE_TENANT_ID" >/dev/null; then
        echo "[-] Azure login failed." >&2
        unset AZURE_LAB_AUTH
        return 1
    fi

    # Set the subscription context
    if ! az account set --subscription "$AZURE_SUBSCRIPTION_ID" >/dev/null; then
        echo "[-] Failed to set subscription $AZURE_SUBSCRIPTION_ID" >&2
        unset AZURE_LAB_AUTH
        return 1
    fi

    # Session marker: this shell intentionally authenticated (like gcplogin/awslogin)
    export AZURE_LAB_AUTH=1

    echo "Azure CLI logged in to: ${AZURE_SUBSCRIPTION_NAME:-$AZURE_SUBSCRIPTION_ID}"
    echo "Run azlogout when finished (same habit as gcplogout / awslogout)."
}


###############################################################################
### Function: Logout from Azure
###############################################################################
azlogout() {
    unset AZURE_LAB_AUTH
    if [ -n "$AZURE_CLIENT_ID" ]; then
        az logout --username "$AZURE_CLIENT_ID" >/dev/null 2>&1 || true
        echo "Azure CLI logged out: $AZURE_CLIENT_ID"
    else
        az logout >/dev/null 2>&1 || true
        echo "Azure CLI logged out (all sessions)."
    fi
}


###############################################################################
### Function: Show current Azure account info
###############################################################################
azshow() {
    az account show --output table
}

###====================================================================================================###
###--- Azure Info Functions
###====================================================================================================###

# List all Azure regions (available to all subscriptions)
azregions() {
    az account list-locations \
        --query '[].{Name:name, DisplayName:displayName, Region:regionalDisplayName}' \
        -o table
}

# List available regions for your current subscription (filtered by your account)
myregions() {
    az account list-locations \
        --query '[].{Name:name, DisplayName:displayName}' \
        -o table
}

list_azvnets() {
    local rg_name="${1:-$AZURE_RESOURCE_GROUP}"

    if [ -z "$rg_name" ]; then
        echo "Usage: azvnets <resource-group>"
        echo "Or set AZURE_RESOURCE_GROUP in your environment."
        return 1
    fi

    echo "Listing VNets in resource group: $rg_name"
    az network vnet list \
        --resource-group "$rg_name" \
        --query '[].{Name:name, Location:location, AddressSpace:addressSpace.addressPrefixes[0]}' \
        -o table
}

list_azsubnets() {
    local rg_name="${1:-$AZURE_RESOURCE_GROUP}"
    local vnet_name="${2}"

    if [ -z "$rg_name" ] || [ -z "$vnet_name" ]; then
        echo "Usage: azsubnets <resource-group> <vnet-name>"
        echo "Or set AZURE_RESOURCE_GROUP in your environment."
        return 1
    fi

    echo "Listing Subnets in VNet: $vnet_name (Resource Group: $rg_name)"
    az network vnet subnet list \
        --resource-group "$rg_name" \
        --vnet-name "$vnet_name" \
        --query '[].{Name:name, AddressPrefix:addressPrefix}' \
        -o table
}

list_azvms() {
    local rg_name="${1:-$AZURE_RESOURCE_GROUP}"

    if [ -z "$rg_name" ]; then
        echo "Usage: azvms <resource-group>"
        echo "Or set AZURE_RESOURCE_GROUP in your environment."
        return 1
    fi

    echo "Listing VMs in resource group: $rg_name"
    az vm list \
        --resource-group "$rg_name" \
        --show-details \
        --query '[].{
            Name:name,
            Location:location,
            Size:hardwareProfile.vmSize,
            PowerState:powerState,
            PrivateIP:privateIps,
            PublicIP:publicIps
        }' \
        -o table
}

list_azdisks() {
    local rg_name="${1:-$AZURE_RESOURCE_GROUP}"

    if [ -z "$rg_name" ]; then
        echo "Usage: azdisks <resource-group>"
        echo "Or set AZURE_RESOURCE_GROUP in your environment."
        return 1
    fi

    echo "Listing Managed Disks in resource group: $rg_name"
    az disk list \
        --resource-group "$rg_name" \
        --query '[].{Name:name, Location:location, SizeGB:diskSizeGb, SKU:sku.name, State:provisioningState}' \
        -o table
}


###=================================================================================================###
###  Aliases
###=================================================================================================###

# --- Azure aliases if az exists
if command -v az >/dev/null 2>&1; then
    alias azauth=az_auth_status
    alias azureauth=az_auth_status
    alias azstatus=az_auth_status
    alias azdisks=list_azdisks
    alias azvms=list_azvms
    alias azsubnets=list_azsubnets
    alias azvnets=list_azvnets
fi