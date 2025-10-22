#!/bin/bash

#==============================================#
# Function: GetMyIP
#==============================================#
GetMyIP() {
  # Get public IP info from ipinfo.io
  response=$(curl -s https://ipinfo.io)
  my_ip=$(echo "$response" | jq -r '.ip')

  # Display to the screen
  echo
  echo "Current Router/VPN IP: $my_ip"
  echo

  # Export environment variable for later use
  export MYIP="$my_ip"
}

GetMyIP


# Create alias like in PowerShell
alias myip=GetMyIP
