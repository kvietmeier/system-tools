#!/bin/bash
#
# setup_git.sh - Automates Git installation and configuration, including secure PAT setup
#
# Created by: Karl Vietmeier
# License: Apache
#

set -euo pipefail

### Variables
IFS=$'\n\t'

# --- Functions ---

# Detect and install Git
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

# Set up Git user configuration
configure_git() {
    read -p "Enter your full name for Git commits: " your_name
    read -p "Enter your GitHub username: " user_name
    read -p "Enter your email address: " your_email
    read -p "Enter your preferred Git editor (default: vim): " editor
    editor=${editor:-vim}
    read -p "Enter your default Git branch name (default: main): " branch
    branch=${branch:-main}

    git config --global user.name "$your_name"
    git config --global user.email "$your_email"
    git config --global core.editor "$editor"
    git config --global init.defaultBranch "$branch"
    git config --global credential.helper store

    setup_pat "$user_name"
}

# Handle GitHub PAT seperately 
setup_pat() {
    local user_name="$1"
    read -p "Enter your GitHub Personal Access Token (PAT): " PAT
    echo

    git credential reject <<EOF
protocol=https
host=github.com
EOF

    printf "protocol=https\nhost=github.com\nusername=%s\npassword=%s\n" "$user_name" "$PAT" | git credential approve
}

# Create or reuse ~/projects directory
prepare_projects_dir() {
    PROJECTS_DIR="$HOME/projects"
    if [ ! -d "$PROJECTS_DIR" ]; then
        echo "Creating projects directory at $PROJECTS_DIR..."
        mkdir -p "$PROJECTS_DIR"
    else
        echo "Using existing projects directory at $PROJECTS_DIR..."
    fi
}

# Clone multiple repos into the projects directory
clone_repos_from_file() {
    read -p "Enter the path to a file containing Git repo URLs to clone (or press Enter to skip): " repo_list_file

    if [ -n "$repo_list_file" ] && [ -f "$repo_list_file" ]; then
        echo "Cloning repositories from $repo_list_file into $PROJECTS_DIR..."
        while IFS= read -r repo_url; do
            [[ -z "$repo_url" || "$repo_url" =~ ^# ]] && continue
            echo "Cloning: $repo_url"
            git -C "$PROJECTS_DIR" clone "$repo_url"
        done < "$repo_list_file"
    else
        echo "No valid repo list provided. Skipping cloning."
    fi
}

# --- Main Script Execution ---

main() {
    if ! command -v git &> /dev/null; then
        install_git
    else
        echo "Git is already installed: $(git --version)"
    fi

    configure_git
    #prepare_projects_dir
    #clone_repos_from_file

    echo -e "\nGit setup complete!"
    git --version
    git config --list | grep -E 'user.name|user.email|core.editor|init.defaultBranch|credential.helper'
}

main
