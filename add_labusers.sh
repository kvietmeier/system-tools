#!/bin/bash
# =============================================================================
# Script to create lab users (labuser01 - labuser05) on bastion host
# - Adds shared public SSH key to each user's authorized_keys (for SSH login)
# - Copies vastadmin.key private key to each user's .ssh directory (for VAST cluster access)
# - Copies .bashrc, .bash_aliases, and .ssh/config from 'karlv' user
# - Sets proper ownership and permissions on all files and directories
#
# Usage:
#   sudo ./create_lab_users.sh
#
# Prerequisites:
#   - Shared public key file path in SHARED_KEY_PUB
#   - vastadmin.key private key path in VAST_KEY_SOURCE
#   - 'karlv' user exists with the config/bash files to copy
# =============================================================================

SOURCE_USER="karlv"

SHARED_KEY_PUB="/home/${SOURCE_USER}/.ssh/other_keys/labuser.key.pub"
VAST_KEY_SOURCE="/home/${SOURCE_USER}/.ssh/other_keys/vastadmin.key.priv"

# Check keys exist
if [ ! -f "$SHARED_KEY_PUB" ]; then
  echo "ERROR: Shared public key not found at $SHARED_KEY_PUB"
  exit 1
fi
if [ ! -f "$VAST_KEY_SOURCE" ]; then
  echo "ERROR: VAST private key not found at $VAST_KEY_SOURCE"
  exit 1
fi

# Detect OS type for user creation
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo "Cannot detect OS, defaulting to Debian-style adduser."
  OS="debian"
fi

for i in $(seq -w 1 5); do
  USER="labuser0${i}"
  echo "Creating user: $USER"

  if id "$USER" &>/dev/null; then
    echo "User $USER already exists, skipping creation."
  else
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
      adduser --disabled-password --gecos "" "$USER"
    else
      useradd -m -s /bin/bash "$USER"
      # Skipping password lock since SSH password login is disabled in sshd_config
    fi
  fi

  sudo mkdir -p "/home/$USER/.ssh"

  sudo cp "$SHARED_KEY_PUB" "/home/$USER/.ssh/authorized_keys"
  sudo chmod 700 "/home/${USER}/.ssh"
  sudo chmod 600 "/home/${USER}/.ssh/authorized_keys"

  sudo cp "$VAST_KEY_SOURCE" "/home/${USER}/.ssh/vastadmin.key"
  sudo chmod 600 "/home/${USER}/.ssh/vastadmin.key"

  if [ -f "/home/$SOURCE_USER/.ssh/config" ]; then
    sudo cp "/home/$SOURCE_USER/.ssh/config" "/home/$USER/.ssh/config"
    sudo chmod 600 "/home/$USER/.ssh/config"
  fi

  for file in .bashrc .bash_aliases; do
    if [ -f "/home/${SOURCE_USER}/${file}" ]; then
      sudo cp "/home/${SOURCE_USER}/${file}" "/home/$USER/$file"
      sudo chown "$USER:$USER" "/home/$USER/$file"
    fi
  done

  sudo chown -R "$USER:$USER" "/home/$USER/.ssh"

  echo "User $USER setup completed."
done

echo "All users created and configured successfully."
