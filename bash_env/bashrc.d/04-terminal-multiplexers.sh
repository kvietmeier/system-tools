#!/bin/bash
###############################################################################
# 06-terminal-multiplexers.sh
# Setup tmux and screen
# Created by Karl Vietmeier
###############################################################################

# --- Tmux Settings ---
# Ensure Tmux uses 256 colors for pretty syntax highlighting
export TERM="xterm-256color"

# Alias to start tmux with a shared session name 'main'
alias tm='tmux attach -t main || tmux new -s main'

# --- Screen Settings ---
# Prevent screen from showing the startup copyright notice
alias screen='screen -q'

# --- Utility Aliases ---
alias tl='tmux ls'
alias ta='tmux attach -t'
