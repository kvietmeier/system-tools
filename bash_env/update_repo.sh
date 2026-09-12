#!/bin/bash
###############################################################################
##### File: update_repo.sh
##### Purpose: Sync active workstation config into this bash_env repo.
#####          Default: copy ~/.bashrc.d -> bashrc.d.{darwin|linux}
#####          --all:   also copy shared dotfiles into common/ (secrets scrubbed)
##### Usage: ./update_repo.sh [--all] [target_repo_directory]
#####        (Defaults to this script's directory)
##### Created by Karl Vietmeier
##### License: Apache 2.0
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_ALL=0
REPO_DIR="$SCRIPT_DIR"

usage() {
    cat <<'EOF'
Usage: ./update_repo.sh [--all] [target_repo_directory]

  (default)  Sync ~/.bashrc.d into bashrc.d.darwin or bashrc.d.linux
  --all      Also sync shared dotfiles into common/ (sanitized)

Target defaults to this script's directory.
EOF
}

# Parse args: optional --all and optional repo path (either order)
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            usage
            exit 0
            ;;
        --all)
            SYNC_ALL=1
            ;;
        -*)
            echo "Unknown option: $arg" >&2
            usage >&2
            exit 1
            ;;
        *)
            REPO_DIR="$arg"
            ;;
    esac
done

case "$(uname -s)" in
    Darwin) PLATFORM_DIR="bashrc.d.darwin" ;;
    Linux)  PLATFORM_DIR="bashrc.d.linux" ;;
    *)
        echo "Unsupported OS: $(uname -s)" >&2
        exit 1
        ;;
esac

if [ ! -d "$HOME/.bashrc.d" ]; then
    echo "No ~/.bashrc.d found — nothing to sync." >&2
    exit 1
fi

mkdir -p "$REPO_DIR"
TARGET_BASHRC_D="$REPO_DIR/$PLATFORM_DIR"

echo "🔄 Syncing ~/.bashrc.d -> $TARGET_BASHRC_D/"
rm -rf "$TARGET_BASHRC_D"
mkdir -p "$TARGET_BASHRC_D"
cp -R "$HOME/.bashrc.d/." "$TARGET_BASHRC_D/"
echo "  ✅ bashrc.d sync complete ($PLATFORM_DIR)"

if [ "$SYNC_ALL" -eq 0 ]; then
    echo "Done (bashrc.d only). Use --all to also sync common/dotfiles."
    exit 0
fi

# ---------------------------------------------------------
# --all: shared dotfiles into common/
# ---------------------------------------------------------
COMMON_DIR="$REPO_DIR/common"
mkdir -p "$COMMON_DIR"

echo "🔄 Syncing shared dotfiles -> $COMMON_DIR/ (--all)"

FILES=(
    "bash_aliases"
    "bashrc"
    "dircolors"
    "tmux.conf"
    "vimrc"
)

for file in "${FILES[@]}"; do
    if [ -f "$HOME/.$file" ]; then
        cp "$HOME/.$file" "$COMMON_DIR/$file"
        echo "  Copied ~/.$file -> common/$file"
    fi
done

# Scrub secrets from ~/.bash_environment.sh
SENSITIVE_VARS_LIST=(
    "VMS_USER"
    "VMS_PASSWORD"
    "GOOGLE_APPLICATION_CREDENTIALS"
    "GCP_DEFAULT_PROJECT"
    "GCP_SA_EMAIL"
    "GCP_PROJECT_ID"
    "AZURE_[A-Z_]+"
    "AWS_[A-Z_]+"
    "POLARIS_[A-Z_]+"
    "VASTDATA_[A-Z_]+"
    "TF_VAR_[A-Z_]+"
)
SENSITIVE_PATTERN=$(IFS='|'; echo "${SENSITIVE_VARS_LIST[*]}")

if [ -f "$HOME/.bash_environment.sh" ]; then
    echo "  🔒 Sanitizing ~/.bash_environment.sh -> common/bash_environment"
    sed -E "s/^(export ($SENSITIVE_PATTERN))=.*/\1=/" \
        "$HOME/.bash_environment.sh" > "$COMMON_DIR/bash_environment"
elif [ -f "$HOME/.bash_environment" ]; then
    echo "  🔒 Sanitizing ~/.bash_environment -> common/bash_environment"
    sed -E "s/^(export ($SENSITIVE_PATTERN))=.*/\1=/" \
        "$HOME/.bash_environment" > "$COMMON_DIR/bash_environment"
fi

# Scrub git user identity
if [ -f "$HOME/.gitconfig" ]; then
    echo "  🔒 Sanitizing ~/.gitconfig -> common/gitconfig"
    sed -E 's/^[[:space:]]*name[[:space:]]*=.*/\tname = <insert-name-here>/; s/^[[:space:]]*email[[:space:]]*=.*/\temail = <insert-email-here>/' \
        "$HOME/.gitconfig" > "$COMMON_DIR/gitconfig"
fi

echo "✅ Update complete. Secrets/personal info scrubbed from common/ exports."
