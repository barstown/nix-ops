#!/usr/bin/env bash
# Build a host's configuration ON the host and optionally activate it, so the
# workstation does not need Nix installed.
#
# Usage: remote-rebuild.sh <host> <action> [ref]
#   action  switch | boot | test | dry-activate | diff
#   ref     main (default), any branch/tag/commit pushed to the remote, or
#           "local" to upload the current working tree (incl. uncommitted changes)
#
# <host> is the name you SSH to (e.g. nix-test.lab.internal); its first DNS
# label selects the flake configuration. Addresses live in DNS, not in this repo.
set -Eeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

resolve_host "${1:?host required}"
host="${HOST_NAME}"
target="${HOST_TARGET}"
action="${2:?action required}"
ref="${3:-main}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flake="${NIX_OPS_FLAKE:-github:barstown/nix-ops}"
remote_src=".cache/nix-ops-src"

# Lets the very first deploy work on a host that doesn't have flakes enabled yet.
nix_opts=(--option experimental-features "nix-command flakes")

[[ -d "${root}/hosts/${host}" ]] || log error "Unknown host" "host=${host}"
if grep -q 'NIX-OPS-PLACEHOLDER' "${root}/hosts/${host}/hardware-configuration.nix"; then
    log error "hardware-configuration.nix is still the placeholder" "fix=just host hardware ${host}"
fi

if [[ "${ref}" == "local" ]]; then
    git -C "${root}" rev-parse --git-dir &>/dev/null || log error "ref=local needs the repo to be a git checkout"
    log info "Uploading working tree" "host=${host}"
    # Tracked + untracked-but-not-ignored files, i.e. exactly what a commit would contain.
    # shellcheck disable=SC2029 # remote_src is expanded locally on purpose
    (
        cd "${root}"
        git ls-files -z --cached --others --exclude-standard |
            while IFS= read -r -d '' f; do [[ -e "${f}" ]] && printf '%s\0' "${f}"; done |
            tar --null --files-from=- -czf -
    ) | ssh "${target}" "rm -rf ${remote_src} && mkdir -p ${remote_src} && tar -xzf - -C ${remote_src}"
    remote_home="$(ssh "${target}" 'printf %s "$HOME"')"
    src="path:${remote_home}/${remote_src}#${host}"
else
    src="${flake}/${ref}#${host}"
fi

case "${action}" in
    diff)
        log info "Building and diffing against the running system" "host=${host}" "src=${src}"
        cmd=(nixos-rebuild build "${nix_opts[@]}" --refresh --flake "${src}")
        diff=(nix "${nix_opts[@]}" store diff-closures /run/current-system ./result)
        # shellcheck disable=SC2029 # expand locally on purpose
        ssh "${target}" "cd \"\$(mktemp -d)\" && ${cmd[*]@Q} && ${diff[*]@Q}"
        ;;
    switch | boot | test | dry-activate)
        log info "Running nixos-rebuild ${action}" "host=${host}" "src=${src}"
        cmd=(sudo nixos-rebuild "${action}" "${nix_opts[@]}" --refresh --print-build-logs --flake "${src}")
        # -t so sudo can prompt on hosts that don't have passwordless wheel yet.
        ssh -t "${target}" "${cmd[*]@Q}"
        ;;
    *)
        log error "Unknown action" "action=${action}"
        ;;
esac
