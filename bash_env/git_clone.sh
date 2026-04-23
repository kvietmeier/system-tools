#!/bin/bash
# ==============================================================================
# Usage:
#   ./git_clone.sh <repo_list_file>
#
# Example:
#   ./git_clone.sh repos.txt
#
# Description:
#   Clones all Git repos listed in the provided file into ~/projects.
# ==============================================================================

set -euo pipefail

PROJECTS_DIR="${HOME}/projects"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# --- Functions ---------------------------------------------------------------

install_git() {
    if command -v dnf &> /dev/null; then
        echo "Detected DNF package manager. Installing Git..."
        sudo dnf install -y git
    elif command -v apt &> /dev/null; then
        echo "Detected APT package manager. Installing Git..."
        sudo apt update
        sudo apt install -y git
    else
        echo "Unsupported package manager. Please install Git manually."
        exit 1
    fi
}

prepare_projects_dir() {
    if [ ! -d "$PROJECTS_DIR" ]; then
        echo "Creating projects directory at $PROJECTS_DIR..."
        mkdir -p "$PROJECTS_DIR"
    else
        echo "Using existing projects directory at $PROJECTS_DIR..."
    fi
}

clone_repos_from_file() {
    local repo_list_file="$1"

    if [ ! -f "$repo_list_file" ]; then
        echo "ERROR: Repo list file not found: $repo_list_file"
        exit 1
    fi

    echo "Processing repositories from $repo_list_file..."

    while IFS= read -r repo_url; do
        # Skip blank lines and comments
        [[ -z "$repo_url" || "$repo_url" =~ ^# ]] && continue

        # Extract repo name (strip trailing .git if present)
        repo_name=$(basename "$repo_url")
        repo_name="${repo_name%.git}"
        repo_path="${PROJECTS_DIR}/${repo_name}"

        if [ -d "$repo_path/.git" ]; then
            echo "Skipping existing repo: $repo_name"
        else
            echo "Cloning: $repo_url"
            git -C "$PROJECTS_DIR" clone "$repo_url"
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
        install_git
    else
        echo "Git is already installed: $(git --version)"
    fi

    prepare_projects_dir
    clone_repos_from_file "$repo_file"

    echo -e "\nGit clone complete!"
}

main "$@"