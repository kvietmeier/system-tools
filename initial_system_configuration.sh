#!/bin/bash
# ==================================================================================================
# Copyright (c) 2025 Karl Vietmeier. All rights reserved.
# Licensed under the MIT License. See LICENSE file in the project root for details.
# This script is provided "as is", without warranty of any kind, express or implied.
# ==================================================================================================
# Description:
#   This script configures a fresh Linux system with:
#     - Logging setup for cloud-init and runtime output
#     - Disabling OS/Kernel auto-upgrades for environment stability
#     - User and directory setup (creates labuser, home dirs, sudo rights)
#     - Common shell aliases for root and labuser
#     - Package installation (development tools, libraries, docker, nfs, etc.)
#     - Chrony configuration with cloud-aware time sources
#     - Compilation and installation of performance tools (idempotent builds)
# ==================================================================================================

### Safety valves
set -euo pipefail

###====================================================================================###
### 1. Logging & System Lock Waiter
###====================================================================================###
exec > >(tee -a /tmp/compiletools-out.log) 2>&1
echo "compiletools_full.sh started at $(date)"

LOG_FILE="/tmp/cloud-init-out.txt"

wait_for_locks() {
    echo "Checking for system locks..."
    while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/dnf/metadata_lock.pid >/dev/null 2>&1; do
        sleep 5
    done
    while [ -f /etc/passwd.lock ] || [ -f /etc/group.lock ] || [ -f /etc/ptmp ] || [ -f /etc/gtmp ]; do
        sleep 2
    done
}

###====================================================================================###
### 2. Disable OS Auto-Upgrades & Firewalls
###====================================================================================###
echo ">>> [SYSTEM] Disabling auto-upgrades and firewalls..."

if [ -f /etc/debian_version ]; then
    # Disable Ubuntu Unattended Upgrades
    echo 'APT::Periodic::Update-Package-Lists "0";' > /etc/apt/apt.conf.d/20auto-upgrades
    echo 'APT::Periodic::Unattended-Upgrade "0";' >> /etc/apt/apt.conf.d/20auto-upgrades
    systemctl stop unattended-upgrades apt-daily.timer apt-daily-upgrade.timer || true
    systemctl disable unattended-upgrades apt-daily.timer apt-daily-upgrade.timer || true
    systemctl mask unattended-upgrades apt-daily.service apt-daily-upgrade.service || true
    
    # Firewall
    ufw disable || true

elif [ -f /etc/redhat-release ]; then
    # Disable DNF Automatic upgrades
    systemctl stop dnf-automatic.timer || true
    systemctl disable dnf-automatic.timer || true
    
    # Firewall
    systemctl stop firewalld nftables || true
    systemctl disable firewalld nftables || true
fi

###====================================================================================###
### 3. User and Directory Setup
###====================================================================================###
wait_for_locks
if ! id -u labuser >/dev/null 2>&1; then
    if [ -f /etc/debian_version ]; then
        useradd -m -s /bin/bash -G sudo labuser
    elif [ -f /etc/redhat-release ]; then
        useradd -m -s /bin/bash -G wheel labuser
    fi
    echo "labuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/labuser
fi

LABUSER_HOME="/home/labuser"
mkdir -p "$LABUSER_HOME/output" "$LABUSER_HOME/git" "/root/git"
chown -R labuser:labuser "$LABUSER_HOME"

ALIASES=$(cat <<'EOF'
alias la="ls -Av"
alias l="ls -CFv"
alias ll='ls -lhvF --group-directories-first'
alias lla='ls -alhvF --group-directories-first'
alias ls="ls -hF --color=auto"
alias grep='grep --color=auto'
alias cdb='cd -'
alias cdu='cd ..'
alias df='df -kh'
alias du='du -h'
set -o vi
bind 'set bell-style none'
EOF
)
echo "$ALIASES" >> "$LABUSER_HOME/.bashrc"
echo "$ALIASES" >> /root/.bashrc

###====================================================================================###
### 4. Package Installation
###====================================================================================###
wait_for_locks
if [ -f /etc/debian_version ]; then
    DEBIAN_FRONTEND=noninteractive apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential libboost-dev libssl-dev libncurses-dev libnuma-dev \
        libaio-dev librdmacm1 cmake autoconf libcurl4-openssl-dev uuid-dev \
        zlib1g-dev git python3-dev libarchive-dev chrony
elif [ -f /etc/redhat-release ]; then
    dnf groupinstall -y "Development Tools"
    dnf install -y epel-release
    dnf install -y numactl-devel libaio-devel boost-devel ncurses-devel \
        openssl-devel cmake rdma-core libcurl-devel libuuid-devel \
        zlib zlib-devel git python3-devel libarchive-devel chrony
fi

###====================================================================================###
### 5. Chrony Configuration (OCI-Aware)
###====================================================================================###
[ -f /etc/debian_version ] && CHRONY_CONF="/etc/chrony/chrony.conf" || CHRONY_CONF="/etc/chrony.conf"

if curl -s --connect-timeout 1 http://169.254.169.254/opc/v1/instance/ >/dev/null 2>&1; then
    echo "server 169.254.169.254 iburst" > $CHRONY_CONF
elif curl -s --connect-timeout 1 http://169.254.169.254/latest/meta-data/ >/dev/null 2>&1; then
    echo "server 169.254.169.123 prefer iburst" > $CHRONY_CONF
else
    echo "pool pool.ntp.org iburst" > $CHRONY_CONF
fi

cat <<EOF >> $CHRONY_CONF
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
EOF
systemctl enable --now chronyd || systemctl enable --now chrony

###====================================================================================###
### 6. Performance Tools (Idempotent)
###====================================================================================###
_smart_build() {
    local url=$1 dir=$2 cmd=$3
    cd /root/git
    if [ -d "$dir" ]; then
        echo ">>> [SKIP] $dir exists."
    else
        echo ">>> [BUILD] $dir..."
        git clone "$url" "$dir"
        cd "$dir"
        if eval "$cmd"; then
            echo ">>> [SUCCESS] $dir installed."
        else
            echo "!!! [FAIL] $dir failed. Cleaning up."
            cd /root/git && rm -rf "$dir"
            return 1
        fi
    fi
}

_smart_build "https://github.com/scottchiefbaker/dool.git" "dool" "./install.py"
_smart_build "https://github.com/axboe/fio.git" "fio" "./configure && make -j$(nproc) && make install"
_smart_build "https://github.com/esnet/iperf.git" "iperf" "./configure && make -j$(nproc) && make install && echo '/usr/local/lib' > /etc/ld.so.conf.d/iperf.conf && ldconfig"
_smart_build "https://github.com/mellanox/sockperf" "sockperf" "./autogen.sh && ./configure && make -j$(nproc) && make install"

# Elbencho (Rocky 9 Fix)
if [ -f /etc/redhat-release ]; then
    EL_CMD="find . -name 'CMakeCache.txt' -delete && \
            find . -name 'CMakeFiles' -type d -exec rm -rf {} + && \
            export OPENSSL_ROOT_DIR=/usr && export OPENSSL_LIBRARIES=/usr/lib64 && export OPENSSL_INCLUDE_DIR=/usr/include && \
            make S3_SUPPORT=1 -j $(nproc) && \
            make rpm && dnf install -y ./packaging/RPMS/x86_64/elbencho*.rpm"
else
    EL_CMD="make S3_SUPPORT=1 -j $(nproc) && make install"
fi
_smart_build "https://github.com/breuner/elbencho.git" "elbencho" "$EL_CMD"

echo "compiletools_full.sh completed at $(date)" >> "$LOG_FILE"