#!/usr/bin/env bash
# =============================================================================
# iterm2  session-tools.sh 
# Strip ANSI escape codes from iTerm2 logs, archive them into structured folders,
# and compress large logs. 
# =============================================================================
# Copyright 2026
# Licensed under the Apache License, Version 2.0 (the "License");
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# 
# SUMMARY:
# Complete logging management for iTerm2 sessions.
# This script provides an on-demand toolset (`terminal_log`) to process raw 
# iTerm2 logs. It strips messy ANSI escape codes to create readable text files, 
# intelligently archives those files into structured directories (Profile/YYYY-MM), 
# and compresses any logs over 50MB into .tar.gz archives to reclaim disk space.
# It is designed to be sourced in your .bashrc and triggered manually or via cron.
#
# Original Zsh version by joshcough: 
# https://gist.github.com/joshcough/ceef229750c279c320a02ca30f9967c5
#
# Suggested usage:
# 1. Add the following to your .bashrc:
#    export TERMINAL_LOG_DIR="$HOME/.terminal_logs"
#    source /path/to/.iterm-session-tools.sh
# 2. Use the `terminal_log` command to manage your logs:
#    terminal_log view        # Open current session log in VS Code
#    terminal_log archive     # Archive older logs into Profile/YYYY-MM folders
#    terminal_log compress    # Compress logs larger than 50MB
#    terminal_log clean-all   # Clean all root log files    
#    terminal_log list        # List recent logs and archived folders
#
# Suggested crontab entry archive amd cxompress any big logs every month at 2am on the 1st:
# 0 2 1 * * /bin/bash -c "source ~/.bashrc && terminal_log archive && terminal_log compress" >> ~/.terminal_logs/cron_maintenance.log 2>&1#
# 
# Note: This script is designed for macOS with iTerm2 and assumes the presence of certain utilities 
# like `rg` (ripgrep) and `code` (VS Code CLI). Adjust paths and commands as necessary for your environment.
#
# =============================================================================

TERMINAL_LOG_DIR="${TERMINAL_LOG_DIR:-$HOME/.terminal_logs}"

# =============================================================================
# INTERNAL HELPER FUNCTIONS
# =============================================================================

_terminal_log_find() {
    if [[ -d "$TERMINAL_LOG_DIR" ]]; then
        find "$TERMINAL_LOG_DIR" -maxdepth 1 -name "*.log" -exec stat -f "%m %N" {} + 2>/dev/null | \
        sort -n | tail -1 | cut -d' ' -f2-
    fi
}

_terminal_log_clean_file() {
    local log_file="$1"
    if [[ ! -f "$log_file" ]]; then
        return 1
    fi
    
    # Strip ANSI codes and completely silence binary byte warnings by routing errors (2>) to /dev/null
    # LC_CTYPE=C forces col to process binary/malformed bytes without crashing
    perl -pe 's/\e([^\[\]]|\[.*?[a-zA-Z]|\].*?\a)//g' "$log_file" | LC_CTYPE=C col -b 2>/dev/null > "${log_file}.log.txt"
}

_terminal_log_clean_logs() {
    local exclude_current="${1:-false}"
    local current_log=""
    local cleaned_count=0
    
    if [[ "$exclude_current" == "true" ]]; then
        current_log=$(_terminal_log_find)
    fi
    
    while IFS= read -r -d '' log; do
        if [[ "$exclude_current" == "true" && "$log" == "$current_log" ]]; then
            continue
        fi
        
        if [[ ! -f "${log}.log.txt" ]] || [[ "$log" -nt "${log}.log.txt" ]]; then
            if [[ "$exclude_current" == "false" ]]; then
                echo "Cleaning $(basename "$log")"
            fi
            _terminal_log_clean_file "$log"
            ((cleaned_count++))
        fi
    done < <(find "$TERMINAL_LOG_DIR" -maxdepth 1 -name "*.log" -type f -print0 2>/dev/null)
    
    return $cleaned_count
}

_terminal_log_check_file_size() {
    local file="$1"
    local label="$2"
    local warning_size=$((100 * 1024 * 1024)) # 100 MB
    
    local size
    size=$(stat -f%z "$file" 2>/dev/null || echo 0)
    
    if [[ $size -gt $warning_size ]]; then
        local size_mb
        size_mb=$(echo "scale=1; $size / 1024 / 1024" | bc 2>/dev/null)
        echo "⚠️  Large $label: $(basename "$file") (${size_mb}MB)"
        return 0
    fi
    return 1
}

_terminal_log_check_sizes() {
    if [[ -d "$TERMINAL_LOG_DIR" ]]; then
        for file in "$TERMINAL_LOG_DIR"/*.log "$TERMINAL_LOG_DIR"/*.log.txt; do
            [[ -f "$file" ]] || continue
            _terminal_log_check_file_size "$file" "log file"
        done
    fi
}

# =============================================================================
# COMMAND FUNCTIONS
# =============================================================================

_terminal_log_cmd_view() {
    if ! command -v code &> /dev/null; then
        echo "Error: VS Code CLI ('code') is not installed."
        return 1
    fi

    local current_log=$(_terminal_log_find)
    if [[ -n "$current_log" ]]; then
        echo "Cleaning and opening current session log..."
        _terminal_log_clean_file "$current_log"
        code "${current_log}.log.txt"
    else
        echo "No current session log found."
    fi
}

_terminal_log_cmd_archive() {
    if [[ ! -d "$TERMINAL_LOG_DIR" ]]; then
        echo "No log directory found at $TERMINAL_LOG_DIR"
        return 0
    fi
    
    echo "Stripping escape codes and archiving logs into Profile/Month folders..."
    local current_log=$(_terminal_log_find)
    local moved_count=0
    
    for file in "$TERMINAL_LOG_DIR"/*.log "$TERMINAL_LOG_DIR"/*.log.txt; do
        [[ -f "$file" ]] || continue
        
        if [[ "$file" == "$current_log" || "$file" == "${current_log}.txt" ]]; then
            continue
        fi
        
        local target_file="$file"
        
        if [[ "$file" == *.log ]]; then
            _terminal_log_clean_file "$file" > /dev/null
            target_file="${file}.log.txt"
            rm -f "$file"
        fi
        
        local filename=$(basename "$target_file")
        
        local date_chunk=$(echo "$filename" | cut -d'_' -f1)
        local folder_name="${date_chunk:0:4}-${date_chunk:4:2}"
        
        if [[ ! "$folder_name" =~ ^[0-9]{4}-[0-9]{2}$ ]]; then
            folder_name="Misc"
        fi
        
        local profile_name=$(echo "$filename" | cut -d'.' -f2)
        profile_name=$(echo "$profile_name" | sed -E 's/[^a-zA-Z0-9]+/_/g' | sed -E 's/^_|_$//g')
        [[ -z "$profile_name" ]] && profile_name="Unknown"

        local target_dir="$TERMINAL_LOG_DIR/$profile_name/$folder_name"
        mkdir -p "$target_dir"
        mv "$target_file" "$target_dir/"
        ((moved_count++))
    done
    
    echo "✅ Cleaned and archived $moved_count files."
}

_terminal_log_cmd_compress() {
    if [[ ! -d "$TERMINAL_LOG_DIR" ]]; then
        echo "No log directory found at $TERMINAL_LOG_DIR"
        return 0
    fi
    
    echo "Searching for archived logs larger than 50MB to compress..."
    local compressed_count=0
    
    while IFS= read -r -d '' large_file; do
        if [[ -f "$large_file" ]]; then
            local filename=$(basename "$large_file")
            local dir=$(dirname "$large_file")
            
            echo "Compressing: $filename"
            
            if tar -czf "${large_file}.tar.gz" -C "$dir" "$filename" 2>/dev/null; then
                rm -f "$large_file"
                ((compressed_count++))
            else
                echo "❌ Failed to compress $filename"
            fi
        fi
    done < <(find "$TERMINAL_LOG_DIR" -type f -name "*.txt" -size +50M -print0)
    
    if [[ $compressed_count -eq 0 ]]; then
        echo "✅ No large log files needed compression."
    else
        echo "✅ Successfully compressed $compressed_count massive files!"
    fi
}

_terminal_log_cmd_list() {
    echo -e "\nRoot terminal log files:"
    find "$TERMINAL_LOG_DIR" -maxdepth 1 -name "*.log.txt" -exec ls -lht {} + 2>/dev/null | head -n 20
    echo -e "\nArchived folders (Profile/Month):"
    find "$TERMINAL_LOG_DIR" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort | sed "s|$TERMINAL_LOG_DIR/||g" | sed 's|^|  - |'
}

_terminal_log_cmd_rg() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: terminal_log rg <search_pattern>"
        return 1
    fi
    _terminal_log_clean_logs "false" > /dev/null
    rg --type-add "logtxt:*.log.txt" --type logtxt "$@" "$TERMINAL_LOG_DIR"
}

_terminal_log_cmd_help() {
    cat << EOF
📝 TERMINAL LOG - Session Logging Management

SUBCOMMANDS:
  view                       Open current session log in VS Code
  archive                    Move older logs into Profile/YYYY-MM folders
  compress                   Find and compress logs larger than 50MB
  clean-all                  Clean all root log files
  list                       List recent logs and archived folders
  rg <pattern>               Search through ALL logs (including archives)
  sizes                      Check for large log files
  help                       Show this help message
EOF
}

terminal_log() {
    local subcommand="$1"
    shift
    case "$subcommand" in
        "view")         _terminal_log_cmd_view "$@" ;;
        "archive")      _terminal_log_cmd_archive "$@" ;;
        "compress")     _terminal_log_cmd_compress "$@" ;;
        "clean-all")    _terminal_log_clean_logs "false" ;;
        "list")         _terminal_log_cmd_list "$@" ;;
        "rg")           _terminal_log_cmd_rg "$@" ;;
        "sizes")        _terminal_log_check_sizes "$@" ;;
        "--help"|"help"|"") _terminal_log_cmd_help "$@" ;;
        *) echo "Unknown subcommand. Run 'terminal_log help'" && return 1 ;;
    esac
}