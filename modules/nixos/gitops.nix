# Pull-based GitOps: each host periodically rebuilds itself from the default
# branch of the public Git repo, the way Flux reconciles a cluster. Branch
# protection plus CI (which builds every host) keeps broken commits off main.
{ config, lib, ... }:
let
  cfg = config.ops.gitops;
in
{
  options.ops.gitops = {
    enable = lib.mkEnableOption "periodic self-rebuild from the Git repository";

    flake = lib.mkOption {
      type = lib.types.str;
      example = "github:owner/repo";
      description = "Flake URI to pull from, without the `#host` suffix.";
    };

    dates = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "systemd calendar expression for when to reconcile.";
    };

    allowReboot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Reboot automatically when a new kernel or initrd lands.";
    };
  };

  config = lib.mkIf cfg.enable {
    system.autoUpgrade = {
      enable = true;
      # Uses the repo's committed flake.lock (it never updates inputs itself);
      # Renovate PRs are how inputs move forward.
      flake = "${cfg.flake}#${config.networking.hostName}";
      flags = [ "--print-build-logs" ];
      operation = "switch";
      inherit (cfg) dates allowReboot;
      randomizedDelaySec = "10min";
      persistent = true;
    };
  };
}
