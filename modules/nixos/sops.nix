# Secrets are decrypted at activation time onto a tmpfs (/run/secrets), never
# into the world-readable /nix/store. Each host decrypts with its own
# post-quantum age key, generated on the host by `just bootstrap host-key`.
{ inputs, ... }:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops.age = {
    keyFile = "/var/lib/sops-nix/key.txt";
    generateKey = false;
    # Don't derive a (classical X25519) key from the SSH host key; use the
    # dedicated PQ key above instead.
    sshKeyPaths = [ ];
  };
  sops.gnupg.sshKeyPaths = [ ];
}
