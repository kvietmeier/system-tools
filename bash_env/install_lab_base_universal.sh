#!/bin/bash
###=============================================================================###
# install_lab_base_universal.sh
#   Lean base toolkit for Lima / lab / demo VMs (macOS + Linux).
#   Intentionally NOT the full cloud SDK stack — use
#   install_cloud_sdks_universal.sh when a demo needs AWS/GCP/Azure/TF.
#
# Packages (best-effort by OS/pkg mgr):
#   From Terraform/scripts/cloud-init packages: (comfort/ops, not the compile suite)
#     tmux git tree numactl wget sysstat jq traceroute nmap bc pkg-config
#   Plus day-to-day lab extras:
#     vim curl python3/pip/venv asciinema htop ripgrep less unzip ca-certificates
#   Explicitly NOT included: build-essential / fio / iperf / elbencho / sockperf
#
# Optional:
#   --configure-git   set user.name / user.email / editor from env or prompts
#   --dotfiles DIR    copy vimrc (and optional gitconfig) from a bash_env/common dir
#
# Env for non-interactive git config:
#   GIT_USER_NAME  GIT_USER_EMAIL  GIT_EDITOR (default: vim)
#
# Usage:
#   ./install_lab_base_universal.sh [--quiet|--verbose] [--configure-git] [--dotfiles DIR]
#
# Created by: Karl Vietmeier
# License: Apache 2.0
###=============================================================================###

set -euo pipefail

QUIET=true
CONFIGURE_GIT=false
DOTFILES_DIR=""
OS_FAMILY=""
PKG_MGR=""
declare -a UPDATE_CMD=()
declare -a INSTALL_CMD=()
declare -a STATUS_LINES=()
FAILED_TOOLS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --quiet)   QUIET=true; shift ;;
        --verbose) QUIET=false; shift ;;
        --configure-git) CONFIGURE_GIT=true; shift ;;
        --dotfiles)
            DOTFILES_DIR="${2:-}"
            if [[ -z "$DOTFILES_DIR" ]]; then
                echo "Error: --dotfiles requires a directory path" >&2
                exit 1
            fi
            shift 2
            ;;
        --dotfiles=*)
            DOTFILES_DIR="${1#*=}"
            shift
            ;;
        -h|--help)
            sed -n '2,28p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

run_cmd() {
    if [[ "$QUIET" == true ]]; then
        "$@" >/dev/null 2>&1
    else
        "$@"
    fi
}

command_exists() { command -v "$1" &>/dev/null; }

mark_ok()   { STATUS_LINES+=("$1|${2:-OK}"); }
mark_fail() { STATUS_LINES+=("$1|Failed"); FAILED_TOOLS+=("$1"); }

detect_os() {
    case "$(uname -s)" in
        Darwin) OS_FAMILY="darwin" ;;
        Linux)  OS_FAMILY="linux" ;;
        *)
            echo "Unsupported OS: $(uname -s)"
            exit 1
            ;;
    esac
}

detect_linux_pkg_mgr() {
    if command_exists apt-get; then
        PKG_MGR="apt"
        UPDATE_CMD=(sudo apt-get update -y)
        INSTALL_CMD=(sudo apt-get install -y)
    elif command_exists dnf; then
        PKG_MGR="dnf"
        UPDATE_CMD=(sudo dnf makecache)
        INSTALL_CMD=(sudo dnf install -y)
    elif command_exists yum; then
        PKG_MGR="yum"
        UPDATE_CMD=(sudo yum makecache)
        INSTALL_CMD=(sudo yum install -y)
    else
        echo "Unsupported package manager (need apt, dnf, or yum)"
        exit 1
    fi
}

###-----------------------------------------------------------------------------###
### Install helpers
###-----------------------------------------------------------------------------###
ensure_pkg() {
    local pkg="$1"
    local bin="${2:-$1}"

    if command_exists "$bin"; then
        mark_ok "$bin" "Already Installed"
        return 0
    fi

    if [[ "$OS_FAMILY" == "darwin" ]]; then
        if brew install "$pkg"; then
            mark_ok "$bin" "Installed"
        else
            mark_fail "$bin"
        fi
        return
    fi

    if run_cmd "${INSTALL_CMD[@]}" "$pkg"; then
        mark_ok "$bin" "Installed"
    else
        # Some distros use alternate names
        mark_fail "$bin"
    fi
}

install_darwin_base() {
    if ! command_exists brew; then
        echo "Homebrew is required on macOS. Install from https://brew.sh and re-run."
        exit 1
    fi

    echo "Installing lab base tools via Homebrew..."
    # Mirror cloud-init comfort list + lab extras (no compile toolchain)
    local pkg
    for pkg in \
        vim git curl wget tree jq tmux htop python asciinema ripgrep \
        numactl sysstat nmap traceroute bc pkg-config
    do
        ensure_pkg "$pkg"
    done
    # pip comes with python formula as pip3
    if command_exists pip3; then
        mark_ok "pip3" "Present"
    else
        mark_ok "pip3" "Missing (check python)"
    fi
}

install_linux_base() {
    detect_linux_pkg_mgr
    echo "Installing lab base tools on Linux ($PKG_MGR)..."
    run_cmd "${UPDATE_CMD[@]}"

    local -a pkgs=()
    case "$PKG_MGR" in
        apt)
            # cloud-init packages: + vim/python/asciinema/htop/rg; no build-essential/fio
            pkgs=(
                vim git curl wget unzip ca-certificates less
                python3 python3-pip python3-venv
                asciinema tree jq tmux htop ripgrep
                numactl sysstat traceroute nmap bc pkg-config
            )
            ;;
        dnf|yum)
            pkgs=(
                vim git curl wget unzip ca-certificates less
                python3 python3-pip python3-venv
                asciinema tree jq tmux htop
                numactl sysstat traceroute nmap bc pkgconf-pkg-config
            )
            ;;
    esac

    local pkg
    for pkg in "${pkgs[@]}"; do
        # Map package → check binary where names differ
        case "$pkg" in
            python3-pip)  command_exists pip3 && { mark_ok "pip3" "Already Installed"; continue; } ;;
            python3-venv) command_exists python3 && [[ -d /usr/lib/python*/venv || -d /usr/lib64/python*/venv ]] && { mark_ok "venv" "Present"; continue; } || true ;;
            ca-certificates) ;;
            ripgrep)      command_exists rg && { mark_ok "rg" "Already Installed"; continue; } ;;
            *)
                local bin="${pkg}"
                [[ "$pkg" == python3 ]] && bin=python3
                command_exists "$bin" && { mark_ok "$bin" "Already Installed"; continue; }
                ;;
        esac

        if run_cmd "${INSTALL_CMD[@]}" "$pkg"; then
            case "$pkg" in
                python3-pip) mark_ok "pip3" "Installed" ;;
                python3-venv) mark_ok "venv" "Installed" ;;
                ripgrep) mark_ok "rg" "Installed" ;;
                ca-certificates) mark_ok "ca-certs" "Installed" ;;
                *) mark_ok "$pkg" "Installed" ;;
            esac
        else
            case "$pkg" in
                ripgrep)
                    # optional on older distros
                    mark_ok "rg" "Skipped"
                    ;;
                *)
                    mark_fail "$pkg"
                    ;;
            esac
        fi
    done

    # dnf/yum: try ripgrep separately
    if [[ "$PKG_MGR" == "dnf" || "$PKG_MGR" == "yum" ]]; then
        if command_exists rg; then
            mark_ok "rg" "Already Installed"
        elif run_cmd "${INSTALL_CMD[@]}" ripgrep; then
            mark_ok "rg" "Installed"
        else
            mark_ok "rg" "Skipped"
        fi
    fi
}

###-----------------------------------------------------------------------------###
### Dotfiles / git
###-----------------------------------------------------------------------------###
install_dotfiles() {
    local dir="${1:-}"
    [[ -n "$dir" && -d "$dir" ]] || return 0

    if [[ -f "$dir/vimrc" && ! -f "${HOME}/.vimrc" ]]; then
        cp "$dir/vimrc" "${HOME}/.vimrc"
        mark_ok "vimrc" "Copied"
    elif [[ -f "${HOME}/.vimrc" ]]; then
        mark_ok "vimrc" "Already Present"
    fi

    # Prefer scrubbed template only if no global gitconfig yet
    if [[ -f "$dir/gitconfig" && ! -f "${HOME}/.gitconfig" ]]; then
        echo "Note: not auto-copying gitconfig (may contain personal identity)."
        echo "      Use --configure-git or: cp $dir/gitconfig ~/.gitconfig && edit."
        mark_ok "gitconfig" "Skipped (manual)"
    fi
}

configure_git() {
    if ! command_exists git; then
        echo "git not installed; cannot configure."
        mark_fail "git-config"
        return 1
    fi

    local name email editor
    name="${GIT_USER_NAME:-}"
    email="${GIT_USER_EMAIL:-}"
    editor="${GIT_EDITOR:-vim}"

    if [[ -z "$name" ]]; then
        read -r -p "Git user.name: " name
    fi
    if [[ -z "$email" ]]; then
        read -r -p "Git user.email: " email
    fi

    git config --global user.name "$name"
    git config --global user.email "$email"
    git config --global core.editor "$editor"
    git config --global init.defaultBranch main

    if [[ "$(uname -s)" == "Darwin" ]]; then
        git config --global credential.helper osxkeychain
    else
        # Lab VMs: prefer SSH; store is fine for HTTPS demos
        git config --global credential.helper store
    fi

    mark_ok "git-config" "Configured"
    echo "Git identity: $(git config --global user.name) <$(git config --global user.email)>"
}

print_summary() {
    echo ""
    echo "====================================="
    echo "Lab base summary ($OS_FAMILY):"
    echo "====================================="
    if [[ ${#STATUS_LINES[@]} -gt 0 ]]; then
        local line name st
        for line in "${STATUS_LINES[@]}"; do
            name="${line%%|*}"
            st="${line#*|}"
            printf "  %-14s %s\n" "$name" "$st"
        done | sort
    fi
    if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
        echo "-------------------------------------"
        echo "Failed:"
        local t
        for t in "${FAILED_TOOLS[@]}"; do
            echo "  - $t"
        done
    fi
    echo "====================================="
    echo "Next (lab shell):"
    echo "  cp server_bashrc_files/bashrc_lab_server.sh ~/.bashrc && source ~/.bashrc"
    echo "Cloud SDKs when needed:"
    echo "  ./install_cloud_sdks_universal.sh"
    echo "====================================="
}

main() {
    detect_os
    case "$OS_FAMILY" in
        darwin) install_darwin_base ;;
        linux)  install_linux_base ;;
    esac

    if [[ -n "$DOTFILES_DIR" ]]; then
        install_dotfiles "$DOTFILES_DIR"
    fi

    if [[ "$CONFIGURE_GIT" == true ]]; then
        configure_git
    fi

    print_summary
    if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
