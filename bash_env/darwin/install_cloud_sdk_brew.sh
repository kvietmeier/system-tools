#!/bin/bash
# Compatibility wrapper — logic lives in ../install_cloud_sdks.sh (Darwin + Linux).
exec "$(cd "$(dirname "$0")/.." && pwd)/install_cloud_sdks.sh" "$@"
