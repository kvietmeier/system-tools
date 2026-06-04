#!/bin/bash
# ==============================================================================
# Usage:
#    ./git_clone.sh <repo_list_file>
#
# Description:
#    Parses a tagged repo file, filters based on the current OS environment,
#    and roots work vs personal repos into their correct folders.
# ==============================================================================

set -euo pipefail

# Define Mac-aware Root Directories
PERSONAL_DIR="${HOME}/repos"
WORK_DIR="${HOME}/repos-vast"

# --- Functions ---------------------------------------------------------------

ensure_target_directories() {
    mkdir -p "$PERSONAL_DIR"
    mkdir -p "$WORK_DIR"
}

clone_repos_from_file() {
    local repo_list_file="$1"

    if [ ! -f "$repo_list_file" ]; then
        echo "ERROR: Repo list file not found: $repo_list_file"
        exit 1
    fi

    echo "Processing repositories from $repo_list_file..."

    while read -r target_tag repo_url; do
        # 1. Skip blank lines and comments
        [[ -z "$target_tag" || "$target_tag" =~ ^# ]] && continue
        [[ -z "$repo_url" ]] && continue

        # 2. Environment Filtering Check (Mac gets All + Linux)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # On Mac, explicitly drop Windows repos, allow all others
            if [[ "$target_tag" == "windows" ]]; then
                echo "箱 Skip: Skipping Windows repo on macOS architecture: $(basename "$repo_url")"
                continue
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # On Linux, skip Windows-specific repos
            if [[ "$target_tag" == "windows" ]]; then
                echo "⏭️  Skipping Windows repo on Linux: $(basename "$repo_url")"
                continue
            fi
        fi

        # 3. Determine Target Location based on Hosting Platform
        if [[ "$repo_url" == *"gitlab"* ]] || [[ "$repo_url" == *"vastdata"* ]]; then
            TARGET_ROOT="$WORK_DIR"
            IDENTITY_EMAIL="karl.vietmeier@vastdata.com"
            CONTEXT="[WORK]"
        else
            TARGET_ROOT="$PERSONAL_DIR"
            IDENTITY_EMAIL="karlv@storagenet.org"
            CONTEXT="[PERSONAL]"
        fi

        # 4. Extract Repo Name
        repo_name=$(basename "$repo_url")
        repo_name="${repo_name%.git}"
        repo_path="${TARGET_ROOT}/${repo_name}"

        # 5. Check and Clone
        if [ -d "$repo_path/.git" ]; then
            echo "$CONTEXT Skipping existing repo: $repo_name"
        else
            echo "$CONTEXT Cloning $repo_name into $TARGET_ROOT..."
            git -C "$TARGET_ROOT" clone "$repo_url"
            
            # 6. Apply local identity tracking
            git -C "$repo_path" config user.email "$IDENTITY_EMAIL"
            echo "   Mapped local identity -> $IDENTITY_EMAIL"
        fi

    done < "$repo_list_file"
}

# --- Main --------------------------------------------------------------------

main() {
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <repo_list_file>"
        exit 1
    fi

    local repo_file="$1"

    if ! command -v git &> /dev/null; then
        echo "Git missing. Please ensure Git is configured before cloning."
        exit 1
    fi

    ensure_target_directories
    clone_repos_from_file "$repo_file"

    echo -e "\n🎉 Git environment cloning routine complete!"
}

main "$@"
