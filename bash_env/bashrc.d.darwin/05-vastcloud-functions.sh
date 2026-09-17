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

# Login to the active context with --non-interactive.
# Staging vs prod is inferred from the context name; credentials come from
# ~/.bash_environment.sh (POLARIS_USER_STAGING/POLARIS_PASSWORD or POLARIS_USER_PROD/POLARIS_PASS_PROD).
vc_login() {
    local current_ctx user pass
    current_ctx=$(vastcloud config current-context 2>/dev/null || echo "Unknown")

    case "$current_ctx" in
        *prod*|*Prod*|*PROD*)
            user="${POLARIS_USER_PROD:-}"
            pass="${POLARIS_PASS_PROD:-}"
            ;;
        *)
            user="${POLARIS_USER_STAGING:-}"
            pass="${POLARIS_PASSWORD:-}"
            ;;
    esac

    if [[ -z "$user" || -z "$pass" ]]; then
        echo "> [ERROR] Missing Polaris credentials for context '$current_ctx' in ~/.bash_environment.sh" >&2
        return 1
    fi

    echo "======================================================================================"
    echo " Initiating Polaris Authentication for active context: $current_ctx"
    echo "======================================================================================"

    printf '%s' "$pass" | vastcloud login \
        --non-interactive \
        --username "$user" \
        --password-stdin \
        "$@"
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

# Non-interactive AWS create from a Polaris pending deployment (--select).
# Env defaults (override as needed):
#   AWS_SUBNET_ID, AWS_SECURITY_GROUP_IDS (comma-separated), AWS_REGION, AWS_ZONE
# Optional: AWS_NAME, AWS_NODES (only if you need to override Polaris nodeCount)
install_aws_cluster() {
    local cluster_name="${1:-${AWS_NAME:-kv-aws-cluster}}"
    local node_count="${2:-${AWS_NODES:-}}"
    local region="${AWS_REGION:-us-east-1}"
    local zone="${AWS_ZONE:-us-east-1a}"
    local subnet="${AWS_SUBNET_ID:-}"
    local sg_ids="${AWS_SECURITY_GROUP_IDS:-${AWS_SECURITY_GROUP_ID:-}}"

    if [[ -z "$subnet" ]]; then
        echo "[-] Error: AWS_SUBNET_ID is required for non-interactive create." >&2
        return 1
    fi
    if [[ -z "$sg_ids" ]]; then
        echo "[-] Error: AWS_SECURITY_GROUP_IDS is required for non-interactive create." >&2
        return 1
    fi

    local -a args=(
        --non-interactive
        --force
        --select "$cluster_name"
        --provider aws
        --region "$region"
        --zone "$zone"
        --subnet "$subnet"
        --aws-security-group-ids "$sg_ids"
        --skip-preflight
        --skip-checker
    )
    # Node count comes from the Polaris deployment unless explicitly overridden.
    if [[ -n "$node_count" ]]; then
        args+=(--nodes "$node_count")
    fi

    echo "Deploying AWS cluster (non-interactive): $cluster_name"
    echo "  region=$region zone=$zone subnet=$subnet sg=$sg_ids${node_count:+ nodes=$node_count}"
    vastcloud cluster create "${args[@]}"
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
    alias clusterhelp='echo "Usage: vccreategcp [name] [nodes]
  vccreateaws [name] [nodes]
  AWS env: AWS_SUBNET_ID AWS_SECURITY_GROUP_IDS [AWS_REGION AWS_ZONE AWS_NAME AWS_NODES]"'
fi
