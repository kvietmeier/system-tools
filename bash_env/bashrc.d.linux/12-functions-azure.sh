###############################################################################
### Azure functions
### File: .bashrc.d/12-functions-azure.sh
### Purpose: 
###  Simplify Azure authentication and related tasks
### Created by Karl Vietmeier
### License: Apache 2.0
###############################################################################

### Assumes environment variables are set in .bash_environment or manually:
# export AZURE_CLIENT_ID="your-client-id"
# export AZURE_CLIENT_SECRET="your-client-secret"
# export AZURE_TENANT_ID="your-tenant-id"
# export AZURE_SUBSCRIPTION_ID="your-subscription-id"
# export AZURE_SUBSCRIPTION_NAME="your-subscription-name"
# export AZURE_TENANT_DOMAIN="your-tenant-domain"
# export AZURE_RESOURCE_GROUP="your-default-resource-group"

###############################################################################
### Helper function: Check current Azure CLI context
###############################################################################
function azcontext() {
    if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
        echo "Variable \$AZURE_SUBSCRIPTION_ID not set. Please define subscription details first."
        return 1
    fi

    # Get current Azure CLI subscription ID
    local current_sub_id
    current_sub_id=$(az account show --query "id" -o tsv 2>/dev/null)

    if [ -z "$current_sub_id" ] || [ "$current_sub_id" != "$AZURE_SUBSCRIPTION_ID" ]; then
        echo ""
        echo "======================================================="
        echo "  No Azure Connection — use 'azlogin' to connect       "
        echo "======================================================="
        echo ""
        return 1
    else
        echo ""
        echo "======================================================================="
        echo "  ${AZURE_SUBSCRIPTION_NAME:-<unknown>} in ${AZURE_TENANT_DOMAIN:-<unknown>} is logged in"
        echo "======================================================================="
        echo ""
    fi
}


###############################################################################
### Function: Login to Azure with a Service Principal
###############################################################################
function azlogin() {
    if [ -z "$AZURE_CLIENT_ID" ] || [ -z "$AZURE_CLIENT_SECRET" ] || \
       [ -z "$AZURE_TENANT_ID" ] || [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
        echo "Missing required variables for Azure CLI Service Principal login."
        echo "Ensure AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID, and AZURE_SUBSCRIPTION_ID are set."
        return 1
    fi

    echo ""
    echo "Authenticating to Azure Subscription: $AZURE_SUBSCRIPTION_ID"
    echo ""

    az login \
        --service-principal \
        --username "$AZURE_CLIENT_ID" \
        --password "$AZURE_CLIENT_SECRET" \
        --tenant "$AZURE_TENANT_ID" >/dev/null

    # Set the subscription context
    az account set --subscription "$AZURE_SUBSCRIPTION_ID" >/dev/null

    echo "Azure CLI logged in to subscription: $AZURE_SUBSCRIPTION_ID"
}


###############################################################################
### Function: Logout from Azure
###############################################################################
function azlogout() {
    if [ -n "$AZURE_CLIENT_ID" ]; then
        az logout --username "$AZURE_CLIENT_ID" >/dev/null
        echo "Azure CLI logged out: $AZURE_CLIENT_ID"
    else
        echo "Variable AZURE_CLIENT_ID not set. Logging out all sessions."
        az logout >/dev/null
    fi
}


###############################################################################
### Function: Show current Azure account info
###############################################################################
function azshow() {
    az account show --output table
}

###====================================================================================================###
###--- Azure Info Functions
###====================================================================================================###

# List all Azure regions (available to all subscriptions)
function azregions() {
    az account list-locations \
        --query '[].{Name:name, DisplayName:displayName, Region:regionalDisplayName}' \
        -o table
}

# List available regions for your current subscription (filtered by your account)
function myregions() {
    az account list-locations \
        --query '[].{Name:name, DisplayName:displayName}' \
        -o table
}

function list_azvnets() {
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

function list_azsubnets() {
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

function lits_azvms() {
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

function lits_azdisks() {
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
    alias azdisks=list_azdisks
    alias azvms=list_azvms
    alias azsubnets=list_azsubnets
    alias azvnets=list_azvnets
    alias azlogin=azlogin
    alias azlogout=azlogout
    alias azshow=azshow
    alias azcontext=azcontext
fi
