#!/bin/bash
#
# install_cloud_sdks.sh - Hyper-Simplified Core Installation Script
# Created by: Karl Vietmeier
# License: Apache
#

set -euo pipefail

# Plain indexed array to track failed installations
FAILED_TOOLS=()

brew_ensure() {
    local name="$1"
    local cask="${2:-false}"
    local flag=""
    
    [ "$cask" = true ] && flag="--cask"

    if brew list $flag "$name" &>/dev/null || command -v "$name" &>/dev/null; then
        echo "✅ $name is already installed."
    else
        echo "🍺 Installing $name..."
        if ! brew install $flag "$name"; then
            echo "❌ Failed to install $name"
            FAILED_TOOLS+=("$name")
        fi
    fi
}

main() {
    echo "🚀 Bootstrapping Cloud Environments via Homebrew..."
    echo "=================================================="

    brew_ensure "azure-cli"
    brew_ensure "awscli"
    brew_ensure "google-cloud-sdk" true
    brew_ensure "oci-cli"
    
    # 💡 The HashiCorp Fix: Add the official tap before attempting install
    echo "🏗️ Adding official HashiCorp Repository Tap..."
    if brew tap hashicorp/tap &>/dev/null; then
        brew_ensure "hashicorp/tap/terraform"
    else
        echo "❌ Failed to add HashiCorp tap."
        FAILED_TOOLS+=("terraform")
    fi
    
    brew_ensure "asciinema"

    echo -e "\n====================================="
    echo "📝 Installation Summary:"
    echo "====================================="
    if [ ${#FAILED_TOOLS[@]} -eq 0 ]; then
        echo "🎉 All cloud SDK tools are successfully ensured!"
    else
        echo "⚠️ The following tools failed to install:"
        for tool in "${FAILED_TOOLS[@]}"; do
            echo "  - $tool"
        done
    fi
    echo "====================================="
    echo "✅ Done!"
}

main
