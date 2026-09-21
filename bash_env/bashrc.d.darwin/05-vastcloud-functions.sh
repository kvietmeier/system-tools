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

# Parse create-helper args: optional select name + execute flag.
# Default is dry-run (print only). Execute with -x/--execute (also -y/--yes, -f/--force).
# Prefer -x over -f: vastcloud itself already uses -f/--force for skip-confirm.
_vc_parse_create_args() {
    _VC_CREATE_NAME=""
    _VC_CREATE_EXECUTE=0
    local arg
    for arg in "$@"; do
        case "$arg" in
            -x|--execute|-y|--yes|-f|--force)
                _VC_CREATE_EXECUTE=1
                ;;
            -h|--help)
                return 2
                ;;
            -*)
                echo "[-] Unknown flag: $arg (use -x to execute)" >&2
                return 1
                ;;
            *)
                if [[ -n "$_VC_CREATE_NAME" ]]; then
                    echo "[-] Unexpected extra argument: $arg" >&2
                    return 1
                fi
                _VC_CREATE_NAME="$arg"
                ;;
        esac
    done
    return 0
}

# Print a shell-escaped command; run it only when execute=1.
_vc_run_or_print() {
    local execute="$1"
    shift
    local cmd_preview
    cmd_preview=$(printf '%q ' "$@")
    cmd_preview="${cmd_preview% }"

    if [[ "$execute" -eq 1 ]]; then
        echo "> Executing: $cmd_preview"
        "$@"
    else
        echo "> Dry-run (pass -x to execute):"
        echo "  $cmd_preview"
    fi
}

# Non-interactive GCP create from a Polaris pending deployment (--select).
# Sticky env (set once per session/lab): GCP_PROJECT_ID GCP_SA_EMAIL GCP_SUBNET
#   GCP_VIP_RANGE GCP_REGION GCP_ZONE
# Per-run: name argument (or GCP_NAME). Node count from Polaris metadata.
#   vccreategcp <polaris-select-name>        # print command only
#   vccreategcp <polaris-select-name> -x     # execute
install_gcp_cluster() {
    _vc_parse_create_args "$@"
    local parse_rc=$?
    if [[ $parse_rc -eq 2 ]]; then
        echo "Usage: vccreategcp [polaris-select-name] [-x|--execute]"
        echo "  Sticky env: GCP_PROJECT_ID GCP_SA_EMAIL GCP_SUBNET GCP_VIP_RANGE GCP_REGION GCP_ZONE"
        echo "  Default is dry-run; pass -x to execute."
        return 0
    elif [[ $parse_rc -ne 0 ]]; then
        return 1
    fi

    local cluster_name="${_VC_CREATE_NAME:-${GCP_NAME:-}}"
    local execute="$_VC_CREATE_EXECUTE"
    local project_id="${GCP_PROJECT_ID:-}"
    local sa_email="${GCP_SA_EMAIL:-}"
    local subnet="${GCP_SUBNET:-}"
    local vips="${GCP_VIP_RANGE:-}"
    local region="${GCP_REGION:-}"
    local zone="${GCP_ZONE:-}"

    local missing=()
    [[ -z "$cluster_name" ]] && missing+=("name-arg-or-GCP_NAME")
    [[ -z "$project_id" ]] && missing+=("GCP_PROJECT_ID")
    [[ -z "$sa_email" ]] && missing+=("GCP_SA_EMAIL")
    [[ -z "$subnet" ]] && missing+=("GCP_SUBNET")
    [[ -z "$vips" ]] && missing+=("GCP_VIP_RANGE")
    [[ -z "$region" ]] && missing+=("GCP_REGION")
    [[ -z "$zone" ]] && missing+=("GCP_ZONE")
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "[-] Error: missing: ${missing[*]}" >&2
        echo "    Usage: vccreategcp <polaris-select-name> [-x]" >&2
        return 1
    fi

    echo "GCP cluster create: $cluster_name"
    echo "  project=$project_id region=$region zone=$zone subnet=$subnet"
    _vc_run_or_print "$execute" \
        vastcloud cluster create \
        --non-interactive \
        --force \
        --select "$cluster_name" \
        --provider gcp \
        --gcp-project-id "$project_id" \
        --gcp-service-account-email "$sa_email" \
        --subnet "$subnet" \
        --protocol-vips "$vips" \
        --region "$region" \
        --zone "$zone" \
        --skip-checker
}

# Non-interactive AWS create from a Polaris pending deployment (--select).
# Sticky env (set once per session/lab): AWS_SUBNET_ID AWS_SECURITY_GROUP_ID
#   (comma-separated for multiple SGs) AWS_REGION AWS_ZONE
# Per-run: name argument (or AWS_NAME). Node count from Polaris metadata.
#   vccreateaws <polaris-select-name>        # print command only
#   vccreateaws <polaris-select-name> -x     # execute
install_aws_cluster() {
    _vc_parse_create_args "$@"
    local parse_rc=$?
    if [[ $parse_rc -eq 2 ]]; then
        echo "Usage: vccreateaws [polaris-select-name] [-x|--execute]"
        echo "  Sticky env: AWS_SUBNET_ID AWS_SECURITY_GROUP_ID AWS_REGION AWS_ZONE"
        echo "  Default is dry-run; pass -x to execute."
        return 0
    elif [[ $parse_rc -ne 0 ]]; then
        return 1
    fi

    local cluster_name="${_VC_CREATE_NAME:-${AWS_NAME:-}}"
    local execute="$_VC_CREATE_EXECUTE"
    local region="${AWS_REGION:-}"
    local zone="${AWS_ZONE:-}"
    local subnet="${AWS_SUBNET_ID:-}"
    # Singular or plural; either may be a comma-separated list of sg-... IDs
    local sg_ids="${AWS_SECURITY_GROUP_ID:-${AWS_SECURITY_GROUP_IDS:-}}"

    local missing=()
    [[ -z "$cluster_name" ]] && missing+=("name-arg-or-AWS_NAME")
    [[ -z "$subnet" ]] && missing+=("AWS_SUBNET_ID")
    [[ -z "$sg_ids" ]] && missing+=("AWS_SECURITY_GROUP_ID")
    [[ -z "$region" ]] && missing+=("AWS_REGION")
    [[ -z "$zone" ]] && missing+=("AWS_ZONE")
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "[-] Error: missing: ${missing[*]}" >&2
        echo "    Usage: vccreateaws <polaris-select-name> [-x]" >&2
        return 1
    fi

    echo "AWS cluster create: $cluster_name"
    echo "  region=$region zone=$zone subnet=$subnet sg=$sg_ids"
    _vc_run_or_print "$execute" \
        vastcloud cluster create \
        --non-interactive \
        --force \
        --select "$cluster_name" \
        --provider aws \
        --region "$region" \
        --zone "$zone" \
        --subnet "$subnet" \
        --aws-security-group-ids "$sg_ids" \
        --skip-preflight \
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
    alias clusterhelp='echo "Sticky env once per lab; name changes per run:
  vccreategcp <polaris-select-name>       # dry-run (print command)
  vccreategcp <polaris-select-name> -x    # execute
  vccreateaws <polaris-select-name> [-x]
  Execute flags: -x/--execute (preferred), also -y/--yes or -f/--force
  GCP sticky: GCP_PROJECT_ID GCP_SA_EMAIL GCP_SUBNET GCP_VIP_RANGE GCP_REGION GCP_ZONE
  AWS sticky: AWS_SUBNET_ID AWS_SECURITY_GROUP_ID AWS_REGION AWS_ZONE
  AWS_SECURITY_GROUP_ID may be comma-separated (sg-aaa,sg-bbb)
  Node count from Polaris deployment metadata."'
fi
