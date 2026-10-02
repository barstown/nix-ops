#!/usr/bin/env -S just --justfile

set lazy
set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

# Bootstrap Recipes
[group: 'Bootstrap']
mod bootstrap ".just/bootstrap.just"

# Flake Recipes
[group: 'Flake']
mod flake ".just/flake.just"

# Host Recipes
[group: 'Host']
mod host ".just/host.just"

# Secret Recipes
[group: 'Sops']
mod sops ".just/sops.just"

[private]
default:
    just -l

[private]
[positional-arguments]
log lvl msg *args:
    gum log -t rfc3339 -s -l "$1" "$2" "${@:3}"
