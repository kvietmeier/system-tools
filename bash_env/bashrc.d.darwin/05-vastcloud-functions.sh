###===============================================================================================###
#    Misc VAST Utilities & Polaris Context Management
#    File: .bashrc.d/05-vastcloud-functions.sh
#    Purpose: Streamline VAST Polaris multi-context login, cluster deployment, and status checks
#    License: Apache 2.0
###===============================================================================================###

unalias vchelp1 vchelp2 vcls vc_ctx vcstat vclogin vccreategcp vccreateaws vcdestroy clusterhelp vcuse vcstatus vcauth 2>/dev/null || true

# Explicitly switch context in ~/.vast/config.yaml
# Resolves shortcuts from POLARIS_CONTEXTS (defined in ~/.bash_environment.sh),
# or accepts a full context name as-is.
vc_context() {
    local input="${1:-}"
    local target_ctx

    if [[ -z "$input" ]]; then
        echo "> [ERROR] Usage: vc_context <shortcut_or_context_name>" >&2
        if declare -p POLARIS_CONTEXTS &>/dev/null && [[ ${#POLARIS_CONTEXTS[@]} -gt 0 ]]; then
            echo "> Available shortcuts (POLARIS_CONTEXTS):" >&2
            local key
            for key in "${!POLARIS_CONTEXTS[@]}"; do
                printf "  %-12s -> %s\n" "$key" "${POLARIS_CONTEXTS[$key]}" >&2
            done
        fi
        return 1
    fi

    if declare -p POLARIS_CONTEXTS &>/dev/null && [[ -n "${POLARIS_CONTEXTS[$input]:-}" ]]; then
        target_ctx="${POLARIS_CONTEXTS[$input]}"
        echo "> Executing: Shortcut matched. Resolving '$input' -> $target_ctx"
    else
        target_ctx="$input"
    fi

    echo "> Executing: vastcloud config use-context $target_ctx"
    if vastcloud config use-context "$target_ctx"; then
        export POLARIS_CONTEXT="$target_ctx"
        export VASTC_CONTEXT="$target_ctx"
        echo "✓ Active Polaris context set to: $target_ctx"
    else
        echo "> [ERROR] Failed to switch Polaris context." >&2
        return 1
    fi
}

# Pure pass-through login wrapper: uses active context from ~/.vast/config.yaml
vc_login() {
    local current_ctx
    current_ctx=$(vastcloud config current-context 2>/dev/null || echo "Unknown")
    echo "======================================================================================"
    echo " Initiating Polaris OIDC Authentication for active context: $current_ctx"
    echo "======================================================================================"

    vastcloud login "$@"
}

# Consolidated Status Utility
vast_status() {
    echo "======================================================"
    echo "  VASTCloud Status"
    echo "======================================================"
    echo "🔹 Active AWS Profile   : ${AWS_PROFILE:-Not Set}"
    echo "🔹 Active VAST Context  : $(vastcloud config current-context 2>/dev/null || echo 'Not Set')"

    echo -e "\n🔹 Polaris Current Context:"
    vastcloud config current-context 2>/dev/null || echo "  (no context active)"

    echo -e "\n🔹 Polaris Authentication Status:"
    vastcloud auth status 2>/dev/null || echo "  (not authenticated)"

    echo -e "\n🔹 Context Inventory:"
    vastcloud config get-contexts 2>/dev/null || echo "  (failed to fetch contexts)"

    echo -e "\n======================================================"
}

install_gcp_cluster() {
    # Dynamically fetch project ID if GCP_PROJECT is unset
    local default_project
    default_project=$(gcloud config get-value project 2>/dev/null)
    
    local project_id="${GCP_PROJECT:-$default_project}"
    local cluster_name="${1:-${GCP_NAME:-kv-gcp-cluster}}"
    local node_count="${2:-${GCP_NODES:-1}}"

    if [[ -z "$project_id" ]]; then
        echo "[-] Error: No GCP Project set in environment or gcloud config." >&2
        return 1
    fi

    echo "Deploying GCP Cluster: $cluster_name with $node_count nodes..."
    vastcloud cluster create \
        --non-interactive \
        --select "$cluster_name" \
        --gcp-project-id "$project_id" \
        --gcp-service-account-email "${GCP_SA_EMAIL:-}" \
        --nodes "$node_count" \
        --protocol-vips "${GCP_VIP_RANGE:-}" \
        --subnet "${GCP_SUBNET:-}" \
        --region "${GCP_REGION:-us-central1}" \
        --zone "${GCP_ZONE:-us-central1-a}" \
        --skip-checker
}

install_aws_cluster() { 
    local cluster_name="${1:-${AWS_NAME:-kv-aws-cluster}}"
    local node_count="${2:-${AWS_NODES:-1}}"

    echo "Deploying AWS Cluster: $cluster_name with $node_count nodes..."
    vastcloud cluster create \
        --non-interactive \
        --select "$cluster_name" \
        --nodes "$node_count" \
        --subnet "${AWS_SUBNET_ID:-}" \
        --aws-security-group-id "${AWS_SECURITY_GROUP_ID:-}" \
        --skip-checker 
}

if command -v vastcloud >/dev/null 2>&1; then
    alias vchelp1='vastcloud --help'
    alias vchelp2='vastcloud cluster create --help'
    alias vcls='vastcloud cluster list'
    alias vc_ctx='vc_context'
    alias vcuse='vc_context'
    alias vcstat='vast_status'
    alias vcstatus='vast_status'
    alias vcauth='vastcloud auth status'
    alias vclogin='vc_login'
    alias vccreategcp='install_gcp_cluster'
    alias vccreateaws='install_aws_cluster'
    alias vcdestroy='vastcloud cluster delete --select'
    alias clusterhelp='echo "Usage: vccreategcp [cluster_name] [node_count]  OR  vccreateaws [cluster_name] [node_count]"'
fi