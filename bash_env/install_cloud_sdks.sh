#!/bin/bash
###=============================================================================###
# install_cloud_sdks.sh 
#    Installi: 
#       Cloud CLIs - Azure, AWS, GCP, OCI
#       Terraform
#       asciinema
#
# Usage:
#   ./install_cloud_sdks.sh [--quiet|--verbose]
# Flags:
#   --quiet: Suppress command output (default)
#   --verbose: Show command output
#
# Licensed under the Apache License, Version 2.0 (the "License");
# You may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
#
###=============================================================================###

set -e

QUIET=true
declare -A STATUS

# Parse flags
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=true ;;
        --verbose) QUIET=false ;;
    esac
done

run_cmd() {
    if [ "$QUIET" = true ]; then
        "$@" > /dev/null
    else
        "$@"
    fi
}

command_exists() {
    command -v "$1" &> /dev/null
}

file_contains() {
    local file=$1
    local text=$2
    grep -qF "$text" "$file" 2>/dev/null
}

detect_pkg_mgr() {
    if command -v apt-get &> /dev/null; then
        PKG_MGR="apt"
        UPDATE_CMD=(sudo apt-get update -y)
        INSTALL_CMD=(sudo apt-get install -y)
    elif command -v dnf &> /dev/null; then
        PKG_MGR="dnf"
        UPDATE_CMD=(sudo dnf makecache)
        INSTALL_CMD=(sudo dnf install -y)
    elif command -v yum &> /dev/null; then
        PKG_MGR="yum"
        UPDATE_CMD=(sudo yum makecache)
        INSTALL_CMD=(sudo yum install -y)
    else
        echo "Unsupported package manager"
        exit 1
    fi
}

# -------------------------
# WSL
# -------------------------
detect_wsl_and_install_wslu() {
    if grep -qi "microsoft" /proc/version; then
        if ! command_exists wslview && [[ "$PKG_MGR" == "apt" ]]; then
            run_cmd "${UPDATE_CMD[@]}"
            run_cmd "${INSTALL_CMD[@]}" wslu
            STATUS[wslu]="Installed"
        else
            STATUS[wslu]="Already Installed"
        fi
        export BROWSER=wslview
    else
        STATUS[wslu]="Skipped"
    fi
}

# -------------------------
# Prerequisites
# -------------------------
install_prereqs() {
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
    STATUS[prereqs]="Installed/Ensured"
}

# -------------------------
# Azure
# -------------------------
install_azure() {
    if ! command_exists az; then
        run_cmd bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
        STATUS[azure]="Installed"
    else
        STATUS[azure]="Already Installed"
    fi
}

# -------------------------
# AWS
# -------------------------
install_aws() {
    if ! command_exists aws; then
        TMP_DIR=$(mktemp -d)
        cd "$TMP_DIR"
        run_cmd curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
        run_cmd unzip -q awscliv2.zip
        run_cmd sudo ./aws/install --update
        cd - > /dev/null
        rm -rf "$TMP_DIR"
        STATUS[aws]="Installed"
    else
        STATUS[aws]="Already Installed"
    fi
}

# -------------------------
# GCP
# -------------------------
install_gcp() {
    if ! command_exists gcloud; then
        if [[ "$PKG_MGR" == "apt" ]]; then
            KEYRING="/usr/share/keyrings/cloud.google.gpg"
            LIST="/etc/apt/sources.list.d/google-cloud-sdk.list"

            if [ ! -f "$KEYRING" ]; then
                run_cmd bash -c "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o $KEYRING"
            fi

            if ! file_contains "$LIST" "packages.cloud.google.com"; then
                echo "deb [signed-by=$KEYRING] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee "$LIST" > /dev/null
            fi

            run_cmd "${UPDATE_CMD[@]}"
            run_cmd "${INSTALL_CMD[@]}" google-cloud-cli
            STATUS[gcp]="Installed"
        else
            STATUS[gcp]="Skipped"
        fi
    else
        STATUS[gcp]="Already Installed"
    fi
}

# -------------------------
# OCI
# -------------------------
install_oci() {
    if ! command_exists oci; then
        run_cmd bash -c "curl -sL https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh | bash -s -- --accept-all-defaults"
        if [ ! -f /usr/local/bin/oci ]; then
            sudo ln -s ~/bin/oci /usr/local/bin/oci || true
        fi
        STATUS[oci]="Installed"
    else
        STATUS[oci]="Already Installed"
    fi
}

# -------------------------
# Terraform
# -------------------------
install_terraform() {
    if ! command_exists terraform; then
        read -p "Terraform not found. Install? (y/n): " install_tf
        if [[ "$install_tf" =~ ^[Yy]$ ]]; then
            if [[ "$PKG_MGR" == "apt" ]]; then
                KEYRING="/usr/share/keyrings/hashicorp-archive-keyring.gpg"
                LIST="/etc/apt/sources.list.d/hashicorp.list"
                if [ ! -f "$KEYRING" ]; then
                    run_cmd bash -c "curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o $KEYRING"
                fi
                if ! file_contains "$LIST" "apt.releases.hashicorp.com"; then
                    echo "deb [signed-by=$KEYRING] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee "$LIST" > /dev/null
                fi
                run_cmd "${UPDATE_CMD[@]}"
                run_cmd "${INSTALL_CMD[@]}" terraform
            fi
            STATUS[terraform]="Installed"
        else
            STATUS[terraform]="Skipped by User"
        fi
    else
        STATUS[terraform]="Already Installed"
    fi
}

# -------------------------
# Asciinema
# -------------------------
install_asciinema() {
    if ! command_exists asciinema; then
        read -p "Asciinema not found. Install? (y/n): " install_ascii
        if [[ "$install_ascii" =~ ^[Yy]$ ]]; then
            run_cmd "${UPDATE_CMD[@]}"
            run_cmd "${INSTALL_CMD[@]}" asciinema
            STATUS[asciinema]="Installed"
        else
            STATUS[asciinema]="Skipped by User"
        fi
    else
        STATUS[asciinema]="Already Installed"
    fi
}

# -------------------------
# MAIN
# -------------------------
main() {
    detect_pkg_mgr
    detect_wsl_and_install_wslu
    install_prereqs
    install_azure
    install_aws
    install_gcp
    install_oci
    install_terraform
    install_asciinema

    echo ""
    echo "====================================="
    echo "📝 Installation Summary:"
    echo "====================================="
    printf "%-15s %-20s\n" "Tool" "Status"
    echo "-------------------------------------"
    for tool in wslu prereqs azure aws gcp oci terraform asciinema; do
        printf "%-15s %-20s\n" "$tool" "${STATUS[$tool]}"
    done
    echo "====================================="
    echo "✅ Done!"
}

main