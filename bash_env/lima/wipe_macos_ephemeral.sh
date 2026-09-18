#!/bin/bash
###=============================================================================###
# wipe_macos_ephemeral.sh  (run on the Mac host)
#
# MacOS Lima VMs (MacOS01, MacOS_Clean, …) are ephemeral bare-node macOS labs:
#   use once → wipe. Do NOT treat them like durable linux labs (vcdev-env / aws-env).
#
# Usage:
#   ./bash_env/lima/wipe_macos_ephemeral.sh              # wipe default names
#   ./bash_env/lima/wipe_macos_ephemeral.sh MacOS01       # wipe specific
#   ./bash_env/lima/wipe_macos_ephemeral.sh --all-macos   # any limactl name matching MacOS*
#
# Created by: Karl Vietmeier
# License: Apache 2.0
###=============================================================================###

set -euo pipefail

DEFAULTS=(MacOS01 MacOS_Clean)

wipe_one() {
  local name="$1"
  if ! limactl list -q 2>/dev/null | grep -qx "$name"; then
    echo "  (skip) $name — not present"
    return 0
  fi
  echo "==> Wiping ephemeral macOS lab: $name"
  limactl stop -f "$name" 2>/dev/null || true
  limactl delete -f "$name"
  echo "    deleted"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,20p' "$0"
  exit 0
fi

if [[ "${1:-}" == "--all-macos" ]]; then
  names="$(limactl list -q 2>/dev/null | grep -E '^MacOS' || true)"
  if [[ -z "$names" ]]; then
    echo "No MacOS* Lima instances found."
    exit 0
  fi
  # shellcheck disable=SC2086
  for n in $names; do wipe_one "$n"; done
  exit 0
fi

if [[ $# -gt 0 ]]; then
  for n in "$@"; do wipe_one "$n"; done
else
  for n in "${DEFAULTS[@]}"; do wipe_one "$n"; done
fi

echo "Done. Recreate next use with limactl create (macOS template) as needed."
