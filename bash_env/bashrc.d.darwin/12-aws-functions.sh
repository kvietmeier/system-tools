###=================================================================================================###
### AWS Authentication Helpers & VAST Polaris Context Sync
### File: .bashrc.d/11-functions-aws.sh
### Purpose: Simplify AWS SSO login via dynamic profile selection and sync VAST Polaris context
### License: Apache 2.0
###=================================================================================================###

###-------------------------------------------------------------------------------------------------###
### 1. Core Login & State Synchronization
###-------------------------------------------------------------------------------------------------###

# Core Login Wrapper with Bidirectional Polaris Sync
awslogin() {
    local input="${1:-${AWS_PROFILE:-}}"
    
    if [[ -z "$input" ]]; then
        echo "> [ERROR] Usage: awslogin <shortcut_or_exact_profile>" >&2
        return 1
    fi

    echo "> Executing: Resolving target profile for input '$input'..."

    # Resolve shortcut if it exists in master map, otherwise use raw input
    if [[ -n "${AWS_SHORTCUTS[$input]:-}" ]]; then
        export AWS_PROFILE="${AWS_SHORTCUTS[$input]}"
        echo "> Executing: Shortcut matched. Exporting AWS_PROFILE=$AWS_PROFILE"
    else
        export AWS_PROFILE="$input"
        echo "> Executing: No shortcut matched. Exporting raw AWS_PROFILE=$AWS_PROFILE"
    fi

    # 1. Authenticate to AWS SSO
    echo "> Executing: aws sso login --profile $AWS_PROFILE"
    if aws sso login --profile "$AWS_PROFILE"; then
        
        # 2. If AWS auth succeeds, sync the VAST Polaris context
        if [[ -n "${AWS_TO_VAST_CTX[$AWS_PROFILE]:-}" ]]; then
            local target_vast_ctx="${AWS_TO_VAST_CTX[$AWS_PROFILE]}"
            echo "> Executing: vastcloud config use-context $target_vast_ctx"
            
            if command -v vastcloud >/dev/null 2>&1; then
                if vastcloud config use-context "$target_vast_ctx" >/dev/null 2>&1; then
                    export POLARIS_CONTEXT="$target_vast_ctx"
                    export VASTC_CONTEXT="$target_vast_ctx"
                    echo "[VAST] Polaris context synced: $VASTC_CONTEXT"
                else
                    echo "> [ERROR] Failed to set vastcloud context." >&2
                fi
            fi
        else
            echo "[VAST] Warning: No mapped VAST context found for AWS profile '$AWS_PROFILE'"
        fi
    else
        echo "> [ERROR] AWS SSO login failed. VAST context not synced." >&2
        return 1
    fi
}

###-------------------------------------------------------------------------------------------------###
### 2. Utility & Diagnostic Functions
###-------------------------------------------------------------------------------------------------###

# Lean auth check (alias: awsauth). Use --line for cloudauth one-liner mode.
aws_auth_status() {
    local line_mode=0
    [[ "${1:-}" == "--line" ]] && line_mode=1

    local GREEN='\033[0;32m' ORANGE='\033[0;33m' RED='\033[0;31m' NC='\033[0m'

    if ! command -v aws &>/dev/null; then
        if [[ $line_mode -eq 1 ]]; then
            echo -e "AWS:      ${RED}CLI not found${NC}"
        else
            echo "AWS: aws CLI not found"
        fi
        return 1
    fi

    local arn
    # awscli output formats: json|text|table|yaml|yaml-stream (no tsv)
    arn=$(aws sts get-caller-identity --query 'Arn' --output text --cli-connect-timeout 5 2>/dev/null)
    local ok=$?

    if [[ $line_mode -eq 1 ]]; then
        echo -ne "AWS:      "
        if [[ $ok -eq 0 && -n "$arn" ]]; then
            echo -e "${GREEN}${arn}${NC} (profile: ${AWS_PROFILE:-default})"
        else
            echo -e "${ORANGE}No valid session (awslogin)${NC}"
        fi
        return 0
    fi

    echo "========================================================"
    echo "               AWS AUTHENTICATION STATUS                "
    echo "========================================================"
    echo "Profile : ${AWS_PROFILE:-none}"
    echo "VAST ctx: ${VASTC_CONTEXT:-${POLARIS_CONTEXT:-none}}"
    if [[ $ok -eq 0 && -n "$arn" ]]; then
        echo -e "Identity: ${GREEN}${arn}${NC}"
        aws sts get-caller-identity --query '{Account:Account, Arn:Arn}' --output table 2>/dev/null
    else
        echo -e "Identity: ${ORANGE}locked / token missing — run awslogin${NC}"
    fi
    echo "========================================================"
}

aws_whoami() {
    aws_auth_status
}

aws_sso_status() {
    echo "> Executing: Checking local SSO cache..."
    local cache_file
    cache_file=$(ls -t ~/.aws/sso/cache/*.json 2>/dev/null | head -n 1)
    if [[ -n "$cache_file" ]]; then
        echo "Active cache footprint found: $cache_file"
    else
        echo "No active SSO cache found."
    fi
}

aws_list_profiles() {
    echo "> Executing: grep '^\[profile ' ~/.aws/config"
    echo "###---  Available AWS Profiles  ---###"
    grep '^\[profile ' ~/.aws/config 2>/dev/null | sed -E 's/^\[profile (.+)\]/\1/' || echo "No profiles found"
}

aws_purge_creds() {
    echo "> Executing: aws sso logout"
    aws sso logout 2>/dev/null || true
    
    echo "> Executing: rm -rf ~/.aws/sso/cache/*"
    rm -rf ~/.aws/sso/cache/* 2>/dev/null
    
    if [[ -f ~/.aws/credentials ]]; then
        echo "> Executing: > ~/.aws/credentials (truncating file)"
        > ~/.aws/credentials
    fi
    unset AWS_PROFILE
    echo "Purge complete. Local workstation memory layer cleared."
}

aws_sso_logout() {
    echo "> Executing: aws sso logout"
    aws sso logout
    echo "All AWS SSO sessions logged out."
}

aws_cli_version() {
    echo "> Executing: aws --version"
    aws --version 2>/dev/null || echo "AWS CLI is not installed."
}


###-------------------------------------------------------------------------------------------------###
### 3. Usage & Help
###-------------------------------------------------------------------------------------------------###

awsusage() {
    echo -e "\n🔹 Available AWS Login Shortcuts:"
    printf "  %-25s %s\n" "SHORTCUT" "MAPPED PROFILE"
    printf "  %-25s %s\n" "--------" "--------------"
    
    for key in "${!AWS_SHORTCUTS[@]}"; do
        printf "  %-25s %s\n" "$key" "${AWS_SHORTCUTS[$key]}"
    done | sort
    
    echo -e "\n💡 Usage: awslogin <shortcut>"
    echo -e "   Example: awslogin poc\n"
}

###-------------------------------------------------------------------------------------------------###
### 4. Fast-Path Standard Commands
###-------------------------------------------------------------------------------------------------###

if command -v aws >/dev/null 2>&1; then
    alias awslist=aws_list_profiles
    alias awsversion=aws_cli_version
    alias awslogout=aws_sso_logout
    alias awspurge=aws_purge_creds
    alias awswho=aws_whoami
    alias awsauth=aws_auth_status
    alias awstatus=aws_sso_status

    # Fast-path wrappers for the three active AWS_SHORTCUTS (poc/qa/rnd)
    awspoc() { awslogin "${1:-poc}"; }
    awsrnd() { awslogin "${1:-rnd}"; }
    awsqa()  { awslogin "${1:-qa}"; }
fi

###-------------------------------------------------------------------------------------------------###
### 5. Function Directory
###-------------------------------------------------------------------------------------------------###

aws_list_funcs() {
    local target_file="${BASH_SOURCE[0]}"

    if [[ ! -f "$target_file" ]]; then
        echo "> [ERROR] Target file not found: $target_file" >&2
        return 1
    fi

    echo -e "\n🔹 Loaded AWS Helper Functions:"
    echo "-----------------------------------"
    grep -E '^[a-zA-Z0-9_-]+\(\) \{' "$target_file" | awk -F'\\(\\)' '{printf "  %-25s\n", $1}' | sort
    echo -e "\n💡 Run 'awsusage' to view SSO shortcuts or 'alias | grep aws' for fast-paths.\n"
}

alias awsfuncs=aws_list_funcs
alias awshelp=awsusage
alias awskeys=awsusage
