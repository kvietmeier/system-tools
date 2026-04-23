#!/bin/bash
###############################################################################
##### File: update_repo.sh
##### Purpose: Syncs active home directory configurations (dotfiles) into 
#####          a local Git repository. Scrubs sensitive cloud credentials 
#####          and personal Git info before copying. Prevents directory nesting.
##### Usage: ./update_repo.sh [target_repo_directory]
#####        (Defaults to ~/projects/scripts/bash_env if no argument is given)
##### Created by Karl Vietmeier
##### License: Licensed under the Apache License, Version 2.0 (the "License");
#####          You may obtain a copy of the License at 
#####          http://www.apache.org/licenses/LICENSE-2.0
###############################################################################


REPO_DIR="${1:-$HOME/projects/scripts/bash_env}"

echo "🔄 Syncing active dotfiles to Git repository at $REPO_DIR..."
mkdir -p "$REPO_DIR"

# ---------------------------------------------------------
# STANDARD EXPORT: Copy basic config files
# ---------------------------------------------------------
# List of standard dotfiles to copy directly (removed bash_environment and gitconfig)
FILES=(
    "bash_aliases"
    "bashrc"
    "dircolors"
    "tmux.conf"
    "vimrc"
)

# Copy standard files and strip the leading dot
for file in "${FILES[@]}"; do
    if [ -f "$HOME/.$file" ]; then
        cp "$HOME/.$file" "$REPO_DIR/$file"
        echo "  Copied ~/.$file -> $REPO_DIR/$file"
    fi
done

# ---------------------------------------------------------
# SECURE EXPORT: Stub out .bash_environment secrets
# ---------------------------------------------------------
# Define your list of sensitive variables here for easy updating.
SENSITIVE_VARS_LIST=(
    "VMS_USER"
    "VMS_PASSWORD"
    "GOOGLE_APPLICATION_CREDENTIALS"
    "GCP_DEFAULT_PROJECT"
    "AZURE_[A-Z_]+"
    "AWS_[A-Z_]+"
)

# Join the array into a single regex pattern separated by pipes (|)
SENSITIVE_PATTERN=$(IFS='|'; echo "${SENSITIVE_VARS_LIST[*]}")

if [ -f "$HOME/.bash_environment" ]; then
    echo "  🔒 Sanitizing and copying ~/.bash_environment -> $REPO_DIR/bash_environment"
    
    # Use sed to find sensitive 'export VAR=value' lines and strip everything after the '='.
    sed -E "s/^(export ($SENSITIVE_PATTERN))=.*/\1=/" "$HOME/.bash_environment" > "$REPO_DIR/bash_environment"
fi

# ---------------------------------------------------------
# SECURE EXPORT: Stub out .gitconfig user details
# ---------------------------------------------------------
if [ -f "$HOME/.gitconfig" ]; then
    echo "  🔒 Sanitizing and copying ~/.gitconfig -> $REPO_DIR/gitconfig"
    
    # Use sed to replace the name and email values with placeholder stubs
    sed -E 's/^[[:space:]]*name[[:space:]]*=.*/\tname = <insert-name-here>/; s/^[[:space:]]*email[[:space:]]*=.*/\temail = <insert-email-here>/' "$HOME/.gitconfig" > "$REPO_DIR/gitconfig"
fi

# ---------------------------------------------------------
# DIRECTORY SYNC: Copy directories, strip dots, and prevent nesting
# ---------------------------------------------------------
# SSH has been completely removed; only syncing bashrc.d
for dir in "bashrc.d"; do
    if [ -d "$HOME/.$dir" ]; then
        echo "  📦 Syncing directory ~/.$dir/ -> $REPO_DIR/$dir/"
        
        # 1. Wipe the old repo directory to ensure a completely clean slate
        rm -rf "$REPO_DIR/$dir"
        
        # 2. Create the brand new target directory explicitly without the dot
        mkdir -p "$REPO_DIR/$dir"
        
        # 3. Use the "/." trick to copy ONLY the contents into the new dot-less folder.
        cp -r "$HOME/.$dir/." "$REPO_DIR/$dir/"
    fi
done

echo "✅ Update complete. Your secrets and personal info are safe from Git!"