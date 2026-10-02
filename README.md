# ❄️ nix-ops

Declarative, GitOps-managed configuration for my NixOS servers. One flake describes every machine; each machine rebuilds itself from this repo's `main` branch, and nothing is configured by hand on the hosts.

## ✨ Features

- **Flakes** with a committed `flake.lock`, so every host builds from exactly the same pinned nixpkgs.
- **Pull-based GitOps**: each host runs `system.autoUpgrade` against this repo (the NixOS equivalent of Flux reconciling a cluster).
- **Secrets** with [sops-nix](https://github.com/Mic92/sops-nix) and **post-quantum** [age](https://github.com/FiloSottile/age) keys (ML-KEM-768 + X25519). Safe to keep in a public repo; see [docs/secrets.md](./docs/secrets.md).
- **No Nix install needed on the workstation**: deploys build on the target host over SSH. Local `just flake …` commands use `nix` if it is installed, otherwise they run Nix in a Podman container.
- Dev env managed with [mise](https://mise.jdx.dev/), tasks with [just](https://just.systems/)
- CI with [GitHub Actions](https://github.com/features/actions): formatting, `nix flake check`, a full build of every host, a closure diff on PRs, and a plaintext-secret guard
- Dependency automation with [Renovate](https://www.mend.io/renovate) (weekly `flake.lock` maintenance, mise tools, Actions)

## 📂 Layout

```text
.
├── flake.nix              # Entry point: inputs + the list of hosts
├── flake.lock             # Pinned input revisions (updated by Renovate)
├── hosts/
│   └── nix-test/
│       ├── default.nix                 # Everything specific to this machine
│       ├── hardware-configuration.nix  # Generated on the machine, then committed
│       └── secrets.sops.yaml           # Encrypted; only you + nix-test can read it
├── modules/nixos/         # Baseline shared by every host
│   ├── default.nix        #   admin user, SSH keys, GitOps repo URL
│   ├── base.nix           #   locale, firewall, base packages
│   ├── gitops.nix         #   ops.gitops.* → system.autoUpgrade
│   ├── nix.nix            #   flakes, GC, store optimisation
│   ├── sops.nix           #   sops-nix wiring (per-host PQ age key)
│   ├── ssh.nix            #   key-only OpenSSH
│   └── users.nix          #   immutable users, admin account
├── secrets/               # (optional) secrets shared by several hosts
├── scripts/               # Helpers behind the just recipes
├── .just/                 # just modules: bootstrap, flake, host, sops
├── .sops.yaml             # Who can decrypt what (public age recipients)
└── .mise/config.toml      # Pinned CLI tools + env
```

The convention: anything every server should have goes in `modules/nixos`. Anything that applies to one machine goes in `hosts/<name>/default.nix`. When a feature is shared by *some* hosts (for example a media stack), make it a module with an `ops.<feature>.enable` option, the way [gitops.nix](./modules/nixos/gitops.nix) does, and turn it on per host.

## ⚙️ How changes reach a server

```text
 edit ─▶ PR ─▶ CI builds every host ─▶ merge to main ─▶ host timer pulls main ─▶ nixos-rebuild switch
                     ▲                                        (hourly, ops.gitops)
 Renovate ───────────┘  (weekly flake.lock bump)
```

- **GitOps (default):** `nixos-upgrade.timer` on each host builds `github:barstown/nix-ops#<hostname>` from `main` and switches to it. The host only ever runs what is on `main`, so protect `main` and require CI.
- **Push (manual):** `just host deploy <host>` does the same thing immediately over SSH. Use `ref=local` to try uncommitted changes before opening a PR.

Every activation creates a new *generation*. If something breaks, `just host rollback <host>` restores the previous one, or pick an older generation from the boot menu.

## 🚀 Getting started (adopting the existing server)

> [!IMPORTANT]
> This config sets `users.mutableUsers = false`: **any user not declared here is removed** at activation, and passwords set with `passwd` are reverted. Make sure `ops.admin.name` in [modules/nixos/default.nix](./modules/nixos/default.nix) matches the account you log in with, and that its `sshKeys` work, before your first deploy.

### 1. Workstation

1. Install [mise](https://mise.jdx.dev/getting-started.html), then in this directory:

    ```sh
    mise trust && mise install
    ```

2. Give each server a DNS record. Recipes take the name you'd SSH to (`just host deploy nix-test.lab.internal`) and use its first label (`nix-test`) to pick `hosts/nix-test` and the flake configuration, so addresses and domains live in DNS rather than in this public repo. If your SSH username differs from your local one, set `NIX_OPS_SSH_USER`.

3. Create your **project-unique** post-quantum admin key. It is written to `~/.config/sops/age/nix-ops.txt` and its public half goes into `.sops.yaml`:

    ```sh
    just bootstrap age-key
    ```

    **Back this file up to your password manager.** Without it (or a host key) the secrets cannot be decrypted.

### 2. Describe the server

1. The host is named `nix-test`. A host's name appears in `flake.nix` (`hosts`), the `hosts/` directory name, and `.sops.yaml` (anchor, placeholder, `path_regex`). It must be a single label without dots.
2. Pull the generated hardware config from the server (this replaces the placeholder):

    ```sh
    just host hardware nix-test.lab.internal
    ```

3. Port the server's current `/etc/nixos/configuration.nix` into `hosts/nix-test/default.nix`: boot loader, networking, services, extra packages. **Copy `system.stateVersion` exactly as it is on the server**; never bump it.
4. Check the defaults in `modules/nixos/` (time zone, admin user, the GitOps repo URL).

### 3. Secrets

```sh
just bootstrap host-key nix-test.lab.internal       # generates a PQ age key ON the server, adds it to .sops.yaml
just bootstrap host-secrets nix-test.lab.internal   # prompts for a console password, stores its hash encrypted
just sops check                        # confirms nothing is committed in plaintext
```

### 4. Publish

```sh
git add -A    # Nix only sees files that git tracks — always `git add` new files
git commit -m "feat: initial NixOS configuration"
gh repo create barstown/nix-ops --public --source . --push
```

On GitHub, protect `main` and require the **Nix Success** check, then enable Renovate for the repo.

### 5. First deploy

Keep an SSH session to the server open while you do this.

```sh
just host diff   nix-test.lab.internal          # build on the server and show what would change
just host deploy nix-test.lab.internal test     # activate, but don't make it the boot default
# in a NEW terminal: confirm `ssh nix-test.lab.internal` and `sudo -v` still work
just host deploy nix-test.lab.internal          # switch for real (and make it the boot default)
```

The first deploy asks for your sudo password. After it, wheel has passwordless sudo and the GitOps timer takes over; `just host status nix-test.lab.internal` shows it working.

## 🧰 Day-to-day

| Command | What it does |
| ------- | ------------ |
| `just host deploy <host> [mode] [ref]` | Build on the host and activate. `mode`: `switch` \| `boot` \| `test` \| `dry-activate`; `ref`: `main`, a branch/sha, or `local` (your working tree) |
| `just host diff <host> [ref]` | Show package/version changes a deploy would make |
| `just host reconcile <host>` | Run the GitOps pull right now |
| `just host status <host>` | GitOps timer and last run's logs |
| `just host rollback <host>` | Go back one generation |
| `just host generations <host>` | List generations |
| `just sops edit <file>` | Edit (or create) an encrypted file |
| `just sops updatekeys` | Re-encrypt everything after changing recipients in `.sops.yaml` |
| `just flake check` / `fmt` / `update` | Evaluate all hosts / format / update `flake.lock` |
| `just flake eval <host> <option>` | Inspect any option, e.g. `services.openssh.settings` |

A typical change: create a branch, edit, `just flake fmt`, then try it with `just host deploy <host> test local` and open a PR. CI builds it, you merge, and the host picks it up within the hour (or run `just host reconcile <host>`).

## ➕ Adding a host

1. Install NixOS on the machine (a minimal ISO install is fine) and give it a DNS record. The directory/flake name is the record's first label (no dots).
2. Copy `hosts/nix-test` to `hosts/<name>` (drop its `secrets.sops.yaml`), and add `<name>` to `hosts` in `flake.nix`.
3. In `.sops.yaml`, add `- &<name> age1pq1-<name>-REPLACE` under `keys:`, a `^hosts/<name>/` creation rule, and add `*<name>` to any shared rules.
4. `just host hardware <name>`, `just bootstrap host-key <name>`, `just bootstrap host-secrets <name>`, `just sops updatekeys`.
5. `git add -A`, then follow [First deploy](#5-first-deploy).

## ⬆️ Upgrading NixOS

Renovate's weekly `flake.lock` PR brings security fixes within the current release. New releases come out every May and November (`YY.05`, `YY.11`). To upgrade, change the `nixpkgs` URL in [flake.nix](./flake.nix), read the release notes, run `just flake update`, and open a PR. Leave `system.stateVersion` alone.

## 🔭 Possible next steps

- [disko](https://github.com/nix-community/disko) + [nixos-anywhere](https://github.com/nix-community/nixos-anywhere): declarative partitioning and one-command installs of new machines.
- [impermanence](https://github.com/nix-community/impermanence): wipe `/` on every boot for a truly immutable system.
- Set `lockFileMaintenance.automerge = true` in [.renovaterc.json5](./.renovaterc.json5) once you trust CI, for fully hands-off updates.
