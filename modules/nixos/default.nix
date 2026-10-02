# Baseline imported by every host. Values set here use lib.mkDefault where a
# host may reasonably want something different, so hosts can override them
# with a plain assignment.
{
  imports = [
    ./base.nix
    ./gitops.nix
    ./nix.nix
    ./qemuGuest.nix
    ./sops.nix
    ./ssh.nix
    ./users.nix
  ];

  ops = {
    # Public flake URI that hosts pull from. Must match your GitHub repo.
    gitops.flake = "github:barstown/nix-ops";

    admin = {
      name = "kyle";
      # Public keys are safe to commit. Taken from https://github.com/barstown.keys
      sshKeys = [
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIAnpnADpe7jl8RuYhs2GTm0yKQCSI/WEE6dlFzt3CJ+JAAAAFHNzaDpZdWJpNUNORkMtT3Jhbmdl"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG9aLA6avrL2GsHt2ensbiNmlP1UA4+NUJs3vShE+dQn"
      ];
    };
  };
}
