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
get_my_ip() {
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


# logson / logsoff
# ----------------
# Uses asciinema which must be installed separately, to record terminal sessions in a shareable format.
# https://docs.asciinema.org/
# logson starts an asciinema session, recording all commands and output in real time.
# Logs are saved in SESSION_LOGS_DIR with a unique filename: hostname_user_timestamp.cast.
# logsoff reminds you to stop logging by pressing Ctrl-D or typing exit.
logson() {

    # Check if asciinema is installed
    if ! command -v asciinema &> /dev/null; then
        echo "❌ asciinema not found. Please install it first."
        return 1
    fi

    mkdir -p $SESSION_LOGS_DIR
    TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
    LOGFILE="${SESSION_LOGS_DIR}/$(hostname)_${USER}_${TIMESTAMP}.cast"

    echo "📄 Logging session to: $LOGFILE"
    echo "💡 Press Ctrl-D or type 'exit' to stop logging"

    asciinema rec $LOGFILE
}

logsoff() {
    echo "🟢 Press Ctrl-D in the asciinema session to stop logging."
}

# List all asciinema logs in SESSION_LOGS_DIR
listlogs() {
    echo "📄 Logs in $SESSION_LOGS_DIR:"
    ls -1t "$SESSION_LOGS_DIR"
}