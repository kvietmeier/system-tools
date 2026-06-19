###===============================================================================================###
#    Misc VAST Utilities
#    File: .bashrc.d/05-functions-vast.sh
#     Purpose: 
#     Functions and aliases for vast services
#    Created by Karl Vietmeier
#    License: Apache 2.0
###===============================================================================================###

### Polaris contexts
# (NOTE: Passwords and User emails should be moved to ~/.bash_environment)
export POLARIS_STAGING_GCP="staging-gcp-clouddev-itdesk124-ctx"
export POLARIS_STAGING_AWS="staging-aws-600627351840-ctx"

# ==============================================================================
# VASTCloud Cluster Deployment Defaults
# ==============================================================================
# sourced from .bashrc.d/01-set-env_variables.sh, but can be overridden by function parameters

# ==============================================================================
# VASTCloud Deployment Functions
# ==============================================================================

# Create GCP cluster
# Usage: install_gcp_cluster [cluster_name] [node_count]
install_gcp_cluster() {
    local cluster_name="${1:-$GCP_NAME}"
    local node_count="${2:-$GCP_NODES}"

    echo "Deploying GCP Cluster: $cluster_name with $node_count nodes..."
    vastcloud cluster create \
        --non-interactive \
        --select "$cluster_name" \
        --gcp-project-id "$GCP_PROJECT" \
        --gcp-service-account-email "$GCP_SA_EMAIL" \
        --nodes "$node_count" \
        --protocol-vips "$GCP_VIP_RANGE" \
        --subnet "$GCP_SUBNET" \
        --region "$GCP_REGION" \
        --zone "$GCP_ZONE" \
        --skip-checker
}

# Create AWS cluster
# Usage: install_aws_cluster [cluster_name] [node_count]
install_aws_cluster() { 
    local cluster_name="${1:-$AWS_NAME}"
    local node_count="${2:-$AWS_NODES}"

    echo "Deploying AWS Cluster: $cluster_name with $node_count nodes..."
    vastcloud cluster create \
        --non-interactive \
        --select "$cluster_name" \
        --nodes "$node_count" \
        --subnet "$AWS_SUBNET_ID" \
        --aws-security-group-id "$AWS_SECURITY_GROUP_ID" \
        --skip-checker 
}

# ==============================================================================
# ==============================================================================
vc_login() {
    case "$1" in
        gcpstage|gcp)
            export POLARIS_CONTEXT="$POLARIS_STAGING_GCP"
            ;;
        awsstage|aws)
            export POLARIS_CONTEXT="$POLARIS_STAGING_AWS"
            ;;
        *)
            echo "Usage: vc_login {gcp|aws}"
            return 1
            ;;
    esac

    echo "######################################################################################"
    echo ""
    echo "Setting context to $POLARIS_CONTEXT and logging in..."
    echo ""
    vastcloud login --username "$POLARIS_USER_STAGING" --password "$POLARIS_PASSWORD"
    echo "  Running: vastcloud login --username $POLARIS_USER_STAGING --password ********"
    echo ""
}

vc_context() {
    case "$1" in
        gcpstage|gcp)
            export POLARIS_CONTEXT="$POLARIS_STAGING_GCP"
            ;;
        awsstage|aws)
            export POLARIS_CONTEXT="$POLARIS_STAGING_AWS"
            ;;
        *)
            echo "Usage: vc_context {gcp|aws}"
            return 1
            ;;
    esac

    echo ""
    echo "Setting context to $POLARIS_CONTEXT"
    echo "Running: vastcloud config use-context $POLARIS_CONTEXT"
    vastcloud config use-context "$POLARIS_CONTEXT"
    echo ""
}

vast_status() {
    echo "======================================================"
    echo "  VASTCloud Status"
    echo "======================================================"

    echo ""
    echo "Running:   vastcloud config current-context"
    # Because $POLARIS_CONTEXT is exported, this should return the pane's isolated context
    vastcloud config current-context 2>/dev/null || echo "  (no context available)"

    echo ""
    echo "Running:   vastcloud auth status"
    vastcloud auth status 2>/dev/null || echo "  (not authenticated)"

    echo ""
    echo "======================================================"
    echo ""
}

### Convenience aliases for vastcloud
alias vchelp1='vastcloud --help'
alias vchelp2='vastcloud cluster create --help'
alias vcls='vastcloud cluster list'
alias vc_ctx='vc_context'
alias vcstat='vast_status'
alias vclogin='vc_login'
alias vccreategcp='install_gcp_cluster'
alias vccreateaws='install_aws_cluster'
alias vcdestroy='vastcloud cluster delete --select'
alias clusterhelp='echo "Usage: vccreategcp [cluster_name] [node_count]  OR  vccreateaws [cluster_name] [node_count]"'
