{ lib, pkgs, ... }:
{
  time.timeZone = lib.mkDefault "America/New_York";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  networking.firewall.enable = true;
  networking.networkmanager.enable = lib.mkDefault true;

  boot.tmp.cleanOnBoot = true;

  # Newest mainline kernel by default (NixOS's own default is the LTS series).
  # Override per host with a plain assignment, e.g. in hosts/<name>/default.nix:
  #   boot.kernelPackages = pkgs.linuxPackages;          # current LTS
  #   boot.kernelPackages = pkgs.linuxPackages_6_18;     # pin a series
  # Out-of-tree modules (e.g. ZFS) can lag behind the newest kernel.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  # Servers don't need the HTML manual or info pages.
  documentation = {
    doc.enable = false;
    info.enable = false;
  };

  environment.systemPackages = with pkgs; [
    age # `age-keygen -pq` for rotating the host's sops key
    curl
    fastfetch
    fish
    git # required by flakes
    htop
    jq
    sops
    vim
    zsh
  ];
}
