# server01 — host-specific configuration.
#
# Port anything host-specific from the server's existing
# /etc/nixos/configuration.nix into this file (services, networking, extra
# packages). Settings already handled by ./modules/nixos (SSH, users, nix,
# locale) can be dropped.
{
  imports = [ ./hardware-configuration.nix ];

  sops.defaultSopsFile = ./secrets.sops.yaml;

  # Copy the boot loader settings from the existing configuration.nix.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  ops.gitops.enable = true;

  # Example of consuming a secret: the plaintext lands at
  # config.sops.secrets."example/api-token".path (/run/secrets/example/api-token)
  # and is only readable by the owner.
  #
  # sops.secrets."example/api-token" = {
  #   owner = "someservice";
  #   restartUnits = [ "someservice.service" ];
  # };

  # Must stay at the release the machine was FIRST installed with, even after
  # upgrading nixpkgs. Copy it from the existing configuration.nix. It controls
  # stateful data migrations, not which package versions you get.
  system.stateVersion = "26.05";

  # --- BEGIN CUSTOM HOST CONFIGURATION ---
  virtualisation.docker.enable = true;
  users.users.kyle.extraGroups = [ "docker" ];
  # --- END CUSTOM HOST CONFIGURATION ---
}
