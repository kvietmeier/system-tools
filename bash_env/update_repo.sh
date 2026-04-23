#!/bin/bash
# update_repo.sh
# Run this to sync your active home directory configs into your Git repo

REPO_DIR="${1:-$HOME/projects/scripts/bash_env}"

echo "🔄 Syncing active dotfiles to Git repository at $REPO_DIR..."
mkdir -p "$REPO_DIR"

# List of standard dotfiles to copy directly (removed bash_environment from this list)
FILES=(
    "bash_aliases"
    "bashrc"
    "dircolors"
    "dircolors.light"
    "gitconfig"
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
# You can use standard variable names or regex wildcards (like AZURE_[A-Z_]+)
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
    # We use double quotes around the sed expression so the $SENSITIVE_PATTERN variable expands properly.
    sed -E "s/^(export ($SENSITIVE_PATTERN))=.*/\1=/" "$HOME/.bash_environment" > "$REPO_DIR/bash_environment"
fi


# ---------------------------------------------------------
# SECURE EXPORT: Stub out .gitconfig user details
# ---------------------------------------------------------
if [ -f "$HOME/.gitconfig" ]; then
    echo "  🔒 Sanitizing and copying ~/.gitconfig -> $REPO_DIR/gitconfig"
    
    # Use sed to replace the name and email values with placeholder stubs, 
    # while leaving the [user] header and other config blocks intact.
    sed -E 's/^[[:space:]]*name[[:space:]]*=.*/\tname = <insert-name-here>/; s/^[[:space:]]*email[[:space:]]*=.*/\temail = <insert-email-here>/' "$HOME/.gitconfig" > "$REPO_DIR/gitconfig"
fi

# Copy .bashrc.d and strip the leading dot
for dir in "bashrc.d"; do
    if [ -d "$HOME/.$dir" ]; then
        cp -r "$HOME/.$dir" "$REPO_DIR/$dir"
        echo "  Copied ~/.$dir/ -> $REPO_DIR/$dir/"
    fi
done

echo ""
echo "✅ Update complete. Your secrets are safe from Git!"
echo ""