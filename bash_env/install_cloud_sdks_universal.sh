#!/bin/bash
###=============================================================================###
# install_cloud_sdks_universal.sh
#   Universal bootstrap for cloud CLIs and lab tools (macOS + Linux):
#     Azure CLI, AWS CLI, Google Cloud SDK, OCI CLI, Terraform, asciinema
#     (+ wslu on WSL)
#
# Usage:
#   ./install_cloud_sdks_universal.sh [--quiet|--verbose]
#
# Detects:
#   macOS (Darwin)  -> Homebrew (incl. HashiCorp tap, gcloud cask)
#   Linux           -> apt / dnf / yum (+ vendor installers where needed)
#
# Created by: Karl Vietmeier
# License: Apache 2.0
###=============================================================================###

set -euo pipefail

QUIET=true
OS_FAMILY=""
PKG_MGR=""
declare -a UPDATE_CMD=()
declare -a INSTALL_CMD=()
declare -A STATUS=()
FAILED_TOOLS=()

for arg in "$@"; do
    case "$arg" in
        --quiet)   QUIET=true ;;
        --verbose) QUIET=false ;;
        -h|--help)
            sed -n '2,20p' "$0"
            exit 0
            ;;
    esac
done

run_cmd() {
    if [[ "$QUIET" == true ]]; then
        "$@" >/dev/null 2>&1
    else
        "$@"
    fi
}

command_exists() {
    command -v "$1" &>/dev/null
}

file_contains() {
    local file=$1
    local text=$2
    grep -qF "$text" "$file" 2>/dev/null
}

mark_ok()   { STATUS["$1"]="${2:-OK}"; }
mark_fail() { STATUS["$1"]="Failed"; FAILED_TOOLS+=("$1"); }

###-----------------------------------------------------------------------------###
### OS / package manager detection
###-----------------------------------------------------------------------------###
detect_os() {
    case "$(uname -s)" in
        Darwin) OS_FAMILY="darwin" ;;
        Linux)  OS_FAMILY="linux" ;;
        *)
            echo "Unsupported OS: $(uname -s)"
            exit 1
            ;;
    esac
}

detect_linux_pkg_mgr() {
    if command_exists apt-get; then
        PKG_MGR="apt"
        UPDATE_CMD=(sudo apt-get update -y)
        INSTALL_CMD=(sudo apt-get install -y)
    elif command_exists dnf; then
        PKG_MGR="dnf"
        UPDATE_CMD=(sudo dnf makecache)
        INSTALL_CMD=(sudo dnf install -y)
    elif command_exists yum; then
        PKG_MGR="yum"
        UPDATE_CMD=(sudo yum makecache)
        INSTALL_CMD=(sudo yum install -y)
    else
        echo "Unsupported package manager (need apt, dnf, or yum)"
        exit 1
    fi
}

###-----------------------------------------------------------------------------###
### macOS / Homebrew
###-----------------------------------------------------------------------------###
brew_ensure() {
    local name="$1"
    local cask="${2:-false}"
    local flag=""
    local short_name="${name##*/}"

    [[ "$cask" == true ]] && flag="--cask"

    if brew list $flag "$name" &>/dev/null || command_exists "$short_name"; then
        mark_ok "$short_name" "Already Installed"
        echo "$short_name is already installed."
        return 0
    fi

    echo "Installing $name..."
    if brew install $flag "$name"; then
        mark_ok "$short_name" "Installed"
    else
        echo "Failed to install $name"
        mark_fail "$short_name"
    fi
}

install_darwin() {
    if ! command_exists brew; then
        echo "Homebrew is required on macOS. Install from https://brew.sh and re-run."
        exit 1
    fi

    echo "Bootstrapping cloud tools via Homebrew..."
    echo "=================================================="

    brew_ensure "azure-cli"
    brew_ensure "awscli"
    brew_ensure "google-cloud-sdk" true
    brew_ensure "oci-cli"

    echo "Adding official HashiCorp tap..."
    if brew tap hashicorp/tap &>/dev/null; then
        brew_ensure "hashicorp/tap/terraform"
    else
        echo "Failed to add HashiCorp tap."
        mark_fail "terraform"
    fi

    brew_ensure "asciinema"
}

###-----------------------------------------------------------------------------###
### Linux helpers
###-----------------------------------------------------------------------------###
detect_wsl_and_install_wslu() {
    if [[ -r /proc/version ]] && grep -qi "microsoft" /proc/version; then
        if ! command_exists wslview && [[ "$PKG_MGR" == "apt" ]]; then
            run_cmd "${UPDATE_CMD[@]}"
            run_cmd "${INSTALL_CMD[@]}" wslu
            mark_ok "wslu" "Installed"
        else
            mark_ok "wslu" "Already Installed / Present"
        fi
        export BROWSER=wslview
    else
        mark_ok "wslu" "Skipped"
    fi
}

install_linux_prereqs() {
    case "$PKG_MGR" in
        apt)
            run_cmd "${UPDATE_CMD[@]}"
            run_cmd "${INSTALL_CMD[@]}" curl gnupg lsb-release ca-certificates unzip python3-venv
            ;;
        dnf|yum)
            run_cmd "${UPDATE_CMD[@]}"
            run_cmd "${INSTALL_CMD[@]}" curl gnupg2 ca-certificates unzip python3 python3-venv || true
            ;;
    esac
    mark_ok "prereqs" "Installed/Ensured"
}

install_linux_azure() {
    if command_exists az; then
        mark_ok "azure" "Already Installed"
        return 0
    fi
    if run_cmd bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"; then
        mark_ok "azure" "Installed"
    else
        mark_fail "azure"
    fi
}

install_linux_aws() {
    if command_exists aws; then
        mark_ok "aws" "Already Installed"
        return 0
    fi

    local arch zip_url
    arch="$(uname -m)"
    case "$arch" in
        x86_64)           zip_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" ;;
        aarch64|arm64)    zip_url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" ;;
        *)
            echo "Unsupported arch for AWS CLI bundle: $arch"
            mark_fail "aws"
            return 1
            ;;
    esac

    local tmp
    tmp="$(mktemp -d)"
    (
        cd "$tmp"
        run_cmd curl -sL "$zip_url" -o awscliv2.zip
        run_cmd unzip -q awscliv2.zip
        run_cmd sudo ./aws/install --update
    )
    local rc=$?
    rm -rf "$tmp"
    if [[ $rc -eq 0 ]]; then
        mark_ok "aws" "Installed"
    else
        mark_fail "aws"
    fi
}

install_linux_gcp() {
    if command_exists gcloud; then
        mark_ok "gcp" "Already Installed"
        return 0
    fi

    if [[ "$PKG_MGR" != "apt" ]]; then
        echo "GCP SDK auto-install currently supported on apt only; install manually for $PKG_MGR."
        mark_ok "gcp" "Skipped ($PKG_MGR)"
        return 0
    fi

    local keyring="/usr/share/keyrings/cloud.google.gpg"
    local list="/etc/apt/sources.list.d/google-cloud-sdk.list"

    if [[ ! -f "$keyring" ]]; then
        run_cmd bash -c "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o $keyring"
    fi
    if ! file_contains "$list" "packages.cloud.google.com"; then
        echo "deb [signed-by=$keyring] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee "$list" >/dev/null
    fi

    run_cmd "${UPDATE_CMD[@]}"
    if run_cmd "${INSTALL_CMD[@]}" google-cloud-cli; then
        mark_ok "gcp" "Installed"
    else
        mark_fail "gcp"
    fi
}

install_linux_oci() {
    if command_exists oci; then
        mark_ok "oci" "Already Installed"
        return 0
    fi
    if run_cmd bash -c "curl -sL https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh | bash -s -- --accept-all-defaults"; then
        if [[ ! -e /usr/local/bin/oci && -x "${HOME}/bin/oci" ]]; then
            sudo ln -sf "${HOME}/bin/oci" /usr/local/bin/oci || true
        fi
        mark_ok "oci" "Installed"
    else
        mark_fail "oci"
    fi
}

install_linux_terraform() {
    if command_exists terraform; then
        mark_ok "terraform" "Already Installed"
        return 0
    fi

    if [[ "$PKG_MGR" != "apt" ]]; then
        echo "Terraform auto-install currently supported on apt only; install manually for $PKG_MGR."
        mark_ok "terraform" "Skipped ($PKG_MGR)"
        return 0
    fi

    local keyring="/usr/share/keyrings/hashicorp-archive-keyring.gpg"
    local list="/etc/apt/sources.list.d/hashicorp.list"
    if [[ ! -f "$keyring" ]]; then
        run_cmd bash -c "curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o $keyring"
    fi
    if ! file_contains "$list" "apt.releases.hashicorp.com"; then
        echo "deb [signed-by=$keyring] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee "$list" >/dev/null
    fi
    run_cmd "${UPDATE_CMD[@]}"
    if run_cmd "${INSTALL_CMD[@]}" terraform; then
        mark_ok "terraform" "Installed"
    else
        mark_fail "terraform"
    fi
}

install_linux_asciinema() {
    if command_exists asciinema; then
        mark_ok "asciinema" "Already Installed"
        return 0
    fi
    run_cmd "${UPDATE_CMD[@]}"
    if run_cmd "${INSTALL_CMD[@]}" asciinema; then
        mark_ok "asciinema" "Installed"
    else
        mark_fail "asciinema"
    fi
}

install_linux() {
    detect_linux_pkg_mgr
    echo "Bootstrapping cloud tools on Linux ($PKG_MGR)..."
    echo "=================================================="

    detect_wsl_and_install_wslu
    install_linux_prereqs
    install_linux_azure
    install_linux_aws
    install_linux_gcp
    install_linux_oci
    install_linux_terraform
    install_linux_asciinema
}

###-----------------------------------------------------------------------------###
### Summary / main
###-----------------------------------------------------------------------------###
print_summary() {
    echo ""
    echo "====================================="
    echo "Installation Summary ($OS_FAMILY):"
    echo "====================================="
    if [[ ${#STATUS[@]} -gt 0 ]]; then
        local tool
        for tool in "${!STATUS[@]}"; do
            printf "  %-14s %s\n" "$tool" "${STATUS[$tool]}"
        done | sort
    fi
    if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
        echo "-------------------------------------"
        echo "Failed:"
        local t
        for t in "${FAILED_TOOLS[@]}"; do
            echo "  - $t"
        done
    fi
    echo "====================================="
    echo "Done!"
}

main() {
    detect_os
    case "$OS_FAMILY" in
        darwin) install_darwin ;;
        linux)  install_linux ;;
    esac
    print_summary

    if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
