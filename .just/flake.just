set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

# Uses a local Nix install when there is one, otherwise runs Nix in a container
# (the store is cached in the `nix-ops-store` volume between runs).
nix := if `command -v nix || true` != "" { "nix" } else { "podman run --rm -i --security-opt label=disable -v nix-ops-store:/nix -v " + justfile_dir() + ":/src -w /src docker.io/nixos/nix:latest nix --extra-experimental-features 'nix-command flakes'" }

[private]
default:
    just -l flake

[doc('Evaluate every host and run flake checks')]
[group('flake')]
check:
    cd "{{ justfile_dir() }}" && {{ nix }} flake check --print-build-logs

[doc('Format all Nix files')]
[group('flake')]
fmt:
    cd "{{ justfile_dir() }}" && {{ nix }} fmt

[doc('Update flake.lock (all inputs, or the ones named)')]
[group('flake')]
update *inputs:
    cd "{{ justfile_dir() }}" && {{ nix }} flake update {{ inputs }}

[doc("Build a host's full system closure locally (what CI does)")]
[group('flake')]
build host:
    cd "{{ justfile_dir() }}" && {{ nix }} build --print-build-logs --no-link \
        ".#nixosConfigurations.{{ replace_regex(host, '\..*', '') }}.config.system.build.toplevel"

[doc('Print a configuration option as the host would see it, e.g. services.openssh.settings')]
[group('flake')]
eval host option:
    cd "{{ justfile_dir() }}" && {{ nix }} eval --json \
        ".#nixosConfigurations.{{ replace_regex(host, '\..*', '') }}.config.{{ option }}"
