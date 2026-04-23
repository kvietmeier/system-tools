#!/bin/bash
# ==============================================================================
# Usage: ./project-sync.sh [pull|push|status]
# Description: Unified sync utility to manage all Git repos in ~/projects.
# ==============================================================================
# Copyright 2026 Karl V.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# ==============================================================================


PROJECTS_DIR="${HOME}/projects"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Function to pull updates
do_pull() {
    echo "--- Pulling (Rebase/Autostash) ---"
    git pull --rebase --autostash
}

# Function to push updates
do_push() {
    if [[ -n $(git status -s) ]]; then
        echo "--- Found changes. Pushing... ---"
        git add .
        git commit -m "Auto-sync: $TIMESTAMP"
        git push
    else
        echo "--- No changes to push. ---"
    fi
}

# Function to check status
do_status() {
    # Check for local uncommitted changes
    if [[ -n $(git status -s) ]]; then
        echo -e "\033[0;33m[!] Uncommitted changes found\033[0m"
    fi

    # Check for commits that haven't been pushed to GitHub
    UPSTREAM=${1:-'@{u}'}
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse "$UPSTREAM")
    if [ "$LOCAL" != "$REMOTE" ]; then
        echo -e "\033[0;32m[↑] Local is ahead/different from GitHub\033[0m"
    fi
}

# --- Main Logic ---

ACTION=$1

if [[ "$ACTION" != "pull" && "$ACTION" != "push" && "$ACTION" != "status" ]]; then
    echo "Usage: $0 {pull|push|status}"
    exit 1
fi

cd "$PROJECTS_DIR" || exit

for d in */ ; do
    if [ -d "$d/.git" ]; then
        echo -e "\n📂 Project: \033[1;34m$d\033[0m"
        cd "$d" || continue
        
        case $ACTION in
            pull)   do_pull ;;
            push)   do_push ;;
            status) do_status ;;
        esac
        
        cd ..
    fi
done

echo -e "\n✅ Done."