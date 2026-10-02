#!/usr/bin/env bash
# Generate a post-quantum age key ON the host (the private key never leaves it)
# and print its public key on stdout. Idempotent: an existing key is kept.
#
# Usage: bootstrap-host-key.sh <host>
#
# stdout carries only the public key; everything else goes to stderr or the
# terminal so prompts (sudo) stay visible.
set -Eeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

resolve_host "${1:?host required}"
target="${HOST_TARGET}"

# Runs as root on the host. Falls back to `nix shell` for age-keygen on hosts
# that don't have this repo's config (which installs age) applied yet.
# The private key stays root-only (0600); key.pub is world-readable so it can
# be fetched without sudo.
# shellcheck disable=SC2016 # expanded by the remote shell, not here
remote_script='
set -euo pipefail
dir=/var/lib/sops-nix
key=$dir/key.txt
keygen() {
    if command -v age-keygen >/dev/null; then
        age-keygen "$@"
    else
        echo "age-keygen not installed; fetching it with nix shell (first run downloads nixpkgs)..." >&2
        nix --extra-experimental-features "nix-command flakes" shell nixpkgs#age --command age-keygen "$@"
    fi
}
install -d -m 0755 "$dir"
chmod 0755 "$dir"
if [ -s "$key" ]; then
    echo "Keeping existing key at $key" >&2
else
    (umask 077 && keygen -pq -o "$key" 2>/dev/null)
    echo "Generated new key at $key" >&2
fi
chmod 0600 "$key"
keygen -y "$key" >"$dir/key.pub"
chmod 0644 "$dir/key.pub"
'

log info "Ensuring post-quantum age key exists (sudo may prompt)" "host=${target}" >&2
# Interactive, and sent to stderr so it is never captured: sudo's prompt stays visible.
ssh -t "${target}" "sudo bash -c ${remote_script@Q}" >&2

pubkey="$(ssh "${target}" cat /var/lib/sops-nix/key.pub)"
[[ "${pubkey}" == age1pq1* ]] || log error "Could not read the host's public key" "host=${target}"
printf '%s\n' "${pubkey}"
