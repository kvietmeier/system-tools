#!/bin/bash
# rehydrate_server.sh
# Run this on a NEW server to deploy configurations from this repo to the home directory

REPO_DIR="$(pwd)"

echo "💧 Rehydrating environment from $REPO_DIR to $HOME..."

# Files to copy to the home directory (adding the dot prefix)
FILES=(
    "bash_aliases"
    "bash_environment"
    "bashrc"
    "dircolors"
    "gitconfig"
    "tmux.conf"
    "vimrc"
)

for file in "${FILES[@]}"; do
    if [ -f "$REPO_DIR/$file" ]; then
        cp "$REPO_DIR/$file" "$HOME/.$file"
        echo "  Deployed $file -> ~/.$file"
    fi
done

# Directories to copy to the home directory (adding the dot prefix)
for dir in "bashrc.d" "ssh"; do
    if [ -d "$REPO_DIR/$dir" ]; then
        cp -r "$REPO_DIR/$dir" "$HOME/.$dir"
        echo "  Deployed $dir/ -> ~/.$dir/"
    fi
done

# Set correct permissions for SSH if it was copied
if [ -d "$HOME/.ssh" ]; then
    chmod 700 "$HOME/.ssh"
    chmod 600 "$HOME/.ssh/"* 2>/dev/null
    echo "  Secured ~/.ssh permissions"
fi

echo "✅ Environment rehydrated!"
echo "Next steps:"
echo "1. Edit ~/.bash_environment to add this specific server's secrets."
echo "2. Run ./install_cloud_sdks.sh to bootstrap AWS, GCP, Azure, and Terraform."
echo "3. Run 'source ~/.bashrc' or restart your terminal."