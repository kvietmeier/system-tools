#!/bin/bash
###=============================================================================###
# recreate_macos_ephemeral.sh  (run on the Mac host)
#
# Wipe + create clean full macOS Lima guests (bare node ≈ brand-new laptop).
# Uses Lima's stock `template:macos` with --plain (no host mounts / brew provision).
# Ephemeral: use once, then wipe_macos_ephemeral.sh
#
# Usage:
#   ./bash_env/lima/recreate_macos_ephemeral.sh
#   ./bash_env/lima/recreate_macos_ephemeral.sh --name MacOS_Clean
#   ./bash_env/lima/recreate_macos_ephemeral.sh --template macos-15 --cpus 6 --memory 8
#   ./bash_env/lima/recreate_macos_ephemeral.sh --start
#
# Created by: Karl Vietmeier
# License: Apache 2.0
###=============================================================================###

set -euo pipefail

TEMPLATE="macos"
CPUS=4
MEMORY=8
DISK=100
START=false
NAMES=(MacOS_Clean MacOS01)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template) TEMPLATE="${2:?}"; shift 2 ;;
    --cpus)     CPUS="${2:?}"; shift 2 ;;
    --memory)   MEMORY="${2:?}"; shift 2 ;;
    --disk)     DISK="${2:?}"; shift 2 ;;
    --name)
      NAMES=("${2:?}")
      shift 2
      ;;
    --start) START=true; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

need() { command -v "$1" >/dev/null || { echo "Missing: $1" >&2; exit 1; }; }
need limactl

for name in "${NAMES[@]}"; do
  if limactl list -q 2>/dev/null | grep -qx "$name"; then
    echo "==> Wiping existing $name..."
    limactl stop -f "$name" 2>/dev/null || true
    limactl delete -f "$name"
  fi

  echo "==> Creating clean macOS guest: $name (template:$TEMPLATE, plain)"
  # --plain ≈ bare laptop: no mounts, no port forwards, no containerd
  limactl create -y \
    --name="$name" \
    --cpus="$CPUS" \
    --memory="$MEMORY" \
    --disk="$DISK" \
    --plain \
    "template:${TEMPLATE}"

  if [[ "$START" == true ]]; then
    echo "==> Starting $name (first boot installs macOS — can take a while)..."
    limactl start -y "$name"
  else
    echo "    Created. Start with: limactl start $name"
  fi
done

echo ""
echo "=============================================="
echo " Clean macOS bare-node guests ready"
echo "=============================================="
echo "  limactl start MacOS_Clean   # or MacOS01"
echo "  limactl shell MacOS_Clean"
echo "  After use: ./bash_env/lima/wipe_macos_ephemeral.sh"
echo "=============================================="
