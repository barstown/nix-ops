{ config, lib, ... }:
let
  cfg = config.ops.admin;
in
{
  options.ops.admin = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "Login name of the administrator account.";
    };
    sshKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "SSH public keys allowed to log in as the administrator.";
    };
  };

  config = {
    # Users are fully declarative: `useradd`/`passwd` changes are reverted on
    # every activation.
    users.mutableUsers = false;

    users.users.${cfg.name} = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = cfg.sshKeys;
      # Console-login password, kept as a hash inside the host's sops file.
      hashedPasswordFile = config.sops.secrets."users/${cfg.name}/hashed-password".path;
    };

    sops.secrets."users/${cfg.name}/hashed-password".neededForUsers = true;

    # Remote deploys run `sudo nixos-rebuild` over SSH; access is key-only.
    security.sudo.wheelNeedsPassword = false;

    assertions = [
      {
        assertion = cfg.sshKeys != [ ];
        message = "ops.admin.sshKeys is empty; with mutableUsers = false you would be locked out.";
      }
    ];
  };
}
