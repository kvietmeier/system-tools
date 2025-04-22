#!/bin/bash

# Usage check
if [ -z "$1" ]; then
  echo "Usage: $0 <new_ip_address>"
  exit 1
fi

NEW_IP="$1"
HOSTS_FILE="/etc/hosts"
BACKUP_FILE="/etc/hosts.bak"

# Check if the hosts file exists
if [ ! -f "$HOSTS_FILE" ]; then
  echo "Error: $HOSTS_FILE does not exist!"
  exit 2
fi

# Backup the hosts file
sudo cp "$HOSTS_FILE" "$BACKUP_FILE"
if [ $? -eq 0 ]; then
  echo "Backup created at $BACKUP_FILE"
else
  echo "Error: Failed to create backup of $HOSTS_FILE"
  exit 3
fi

# Check if "vastvms" already exists
if grep -qE '^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\s+vastvms\b' "$HOSTS_FILE"; then
  sudo sed -i -E "s|^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\s+vastvms\b.*|$NEW_IP vastvms|" "$HOSTS_FILE"
  echo "Updated vastvms IP to $NEW_IP"
else
  echo "$NEW_IP vastvms" | sudo tee -a "$HOSTS_FILE" > /dev/null
  echo "Added new vastvms entry: $NEW_IP"
fi
