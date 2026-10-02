{ lib, ... }:
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      # Lets wheel users push pre-built closures (e.g. `nixos-rebuild --target-host`
      # from a workstation with Nix). Wheel already has passwordless sudo, so this
      # grants nothing new.
      trusted-users = [ "@wheel" ];
    };

    # The system is defined by this flake, not by channels. nixosSystem already
    # pins the `nixpkgs` registry entry and NIX_PATH to the flake's nixpkgs.
    channel.enable = false;

    gc = {
      automatic = true;
      dates = "weekly";
      options = lib.mkDefault "--delete-older-than 30d";
    };
  };
}
