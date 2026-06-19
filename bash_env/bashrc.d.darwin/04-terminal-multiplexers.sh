#!/bin/bash
###===============================================================================================###
###  tmux and screen configuration
###  File: 04-terminal-multiplexers.sh
### 
###  Modified for Apple Silicon Mac OS
###
###  Purpose: Setup tmux and screen
###
###  Created by Karl Vietmeier
###  License: Apache 2.0
###===============================================================================================###

# --- Tmux Settings ---

# Alias to start tmux with a shared session name 'main'
alias tm='tmux attach -t main || tmux new -s main'

# --- Screen Settings ---
# Prevent screen from showing the startup copyright notice
alias screen='screen -q'

# --- Utility Aliases ---
alias tl='tmux ls'
alias ta='tmux attach -t'
