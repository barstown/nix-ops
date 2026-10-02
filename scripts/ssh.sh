#!/usr/bin/env bash
# SSH to a host by its flake name (see resolve_host in lib/common.sh).
#
# Usage: ssh.sh [-t] <host> [command...]
set -Eeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

opts=()
if [[ "${1:-}" == "-t" ]]; then
    opts+=(-t)
    shift
fi
resolve_host "${1:?host required}"
shift

exec ssh "${opts[@]}" "${HOST_TARGET}" "$@"
