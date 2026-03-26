###############################################################################
### Misc utilities
### File: .bashrc.d/03-functions-utility.sh
### Purpose: 
###   Everything else that doesn't fit in the other categories, like custom functions and aliases
### Created by Karl Vietmeier
### License: Apache 2.0
###############################################################################


#==============================================#
# Function: GetMyIP
# Purpose: Get public IP from ipinfo.io and export it
#==============================================#
GetMyIP() {
    # Attempt to get public IP from ipinfo.io
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        response=$(curl -s https://ipinfo.io)
        my_ip=$(echo "$response" | jq -r '.ip // empty')

        if [ -n "$my_ip" ]; then
            echo
            echo "Current Router/VPN IP: $my_ip"
            echo
            export MYIP="$my_ip"
        else
            echo "Unable to retrieve IP from ipinfo.io"
            return 1
        fi
    else
        echo "Error: curl and jq are required to run GetMyIP"
        return 2
    fi
}

# Alias for quick usage
alias myip=GetMyIP

