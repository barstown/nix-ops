{ lib, pkgs, ... }:
{
  time.timeZone = lib.mkDefault "America/New_York";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  networking.firewall.enable = true;

  boot.tmp.cleanOnBoot = true;

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
