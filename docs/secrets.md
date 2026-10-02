# 🔐 Secrets in a public repo

This repository is public. Everything in it is readable by anyone, except values encrypted with [sops](https://github.com/getsops/sops).

## How it works

```text
 your workstation                         nix-test
 ~/.config/sops/age/nix-ops.txt           /var/lib/sops-nix/key.txt   (root, 0600, never leaves the host)
          │ (admin key)                             │ (host key)
          ▼                                         ▼
 hosts/nix-test/secrets.sops.yaml ──── decrypted at activation by sops-nix ───▶ /run/secrets/... (tmpfs)
```

- Every `*.sops.yaml` file is encrypted for the recipients listed in [.sops.yaml](../.sops.yaml): **you** (admin) plus **the host(s) that need it**. A host cannot read another host's file.
- All keys are **post-quantum hybrid** age keys (`age1pq1…`, ML-KEM-768 + X25519), so ciphertext published today stays safe against "harvest now, decrypt later".
- Host keys are generated **on the host** by `just bootstrap host-key <host>`; the private key never crosses the network.
- sops-nix decrypts during activation into `/run/secrets` (RAM only) with per-secret owner and mode. Decrypted values never enter the Nix store.

> [!NOTE]
> Many sops-nix setups derive the host key from the SSH host key (`ssh-to-age`). That produces a classical X25519 key, which would undo the post-quantum protection, so [modules/nixos/sops.nix](../modules/nixos/sops.nix) disables it (`sops.age.sshKeyPaths = [ ]`) in favour of a dedicated PQ key.

## The one rule: never put a secret in a Nix string

The Nix store (`/nix/store`) is **world-readable** on the host, and the source is public on GitHub. Anything written as a literal in a `.nix` file, or interpolated into one with `builtins.readFile`, ends up in both places. Pass services a **path** instead:

```nix
# hosts/nix-test/default.nix
sops.secrets."grafana/admin-password" = {
  owner = "grafana";
  restartUnits = [ "grafana.service" ];
};

services.grafana.settings.security.admin_password =
  "$__file{${config.sops.secrets."grafana/admin-password".path}}";
```

When a program only reads a whole config file, render it with `sops.templates`. The placeholder is replaced at activation time, not in the store:

```nix
sops.secrets."app/token" = { };
sops.templates."app.env" = {
  content = ''
    API_TOKEN=${config.sops.placeholder."app/token"}
  '';
  owner = "app";
};
systemd.services.app.serviceConfig.EnvironmentFile = config.sops.templates."app.env".path;
```

## What is fine to publish

| Fine in the open | Keep encrypted / out of the repo |
| ---------------- | -------------------------------- |
| SSH and age **public** keys | Private keys of any kind |
| Package lists, service config, firewall ports | Passwords, password hashes, API tokens, TLS keys |
| Host names and the internal DNS domain | IP addresses (resolve them through your DNS server) |
| The `.sops.yaml` recipient list | Anything you'd be unhappy to see in a search engine |

Some data isn't secret but you'd still rather not publish it, and it's needed at *evaluation* time (an internal domain name in an nginx `virtualHost`, say). sops can't help there, because secrets only exist at runtime. The options are:

1. Accept it being public (common for homelab domains), or
2. Use `sops.templates` so the value only appears in a runtime-rendered file, or
3. Add a small **private** Git repo as a flake input (`inputs.private.url = "git+ssh://git@github.com/barstown/nix-private"`) holding those values. This works for pushes from your workstation, but the hosts' GitOps pull would then need a deploy key.

## Operations

| Task | How |
| ---- | --- |
| Edit / add a secret | `just sops edit hosts/nix-test/secrets.sops.yaml` |
| Shared secret for several hosts | Create `secrets/<name>.sops.yaml` (the shared rule in `.sops.yaml` lists the hosts), then `sops.secrets.x.sopsFile = ../../secrets/<name>.sops.yaml;` |
| Add a host / change recipients | Edit `.sops.yaml`, then `just sops updatekeys` |
| Rotate a host key | On the host: `sudo rm /var/lib/sops-nix/key.txt`; then `just bootstrap host-key <host>`, replace its old key in `.sops.yaml`, `just sops updatekeys`, deploy |
| Check before committing | `just sops check` (also enforced in CI) |
| Readable `git diff` of secrets | `git config diff.sopsdiffer.textconv "sops decrypt"` (wired up in `.gitattributes`) |

### If a key is lost

- **Admin key lost:** restore it from your password-manager backup (which is why `just bootstrap age-key` tells you to make one). Without a backup, the hosts keep working with their own keys, but you can no longer edit their secrets. Generate a new admin key and re-create each secrets file from the original values.
- **Host key lost** (e.g. reinstall): with your admin key, run the rotate steps above.
- **A key leaked:** remove it from `.sops.yaml`, `just sops updatekeys`, and **change the actual secrets**. Old ciphertext stays in Git history, so re-encrypting alone is not enough.
