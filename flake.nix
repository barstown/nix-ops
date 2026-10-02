{
  description = "Declarative, GitOps-managed NixOS server configurations";

  inputs = {
    # Stable release branch. Bump this twice a year (YY.05 / YY.11) after reading
    # the release notes: https://nixos.org/manual/nixos/stable/release-notes
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;

      # Every server managed by this repo. The attribute name must match the
      # directory under ./hosts and becomes the machine's hostname.
      hosts = {
        nix-test = {
          system = "x86_64-linux";
        };
      };

      mkHost =
        hostname:
        { system }:
        lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            {
              networking.hostName = hostname;
              nixpkgs.hostPlatform = system;
            }
            ./modules/nixos
            ./hosts/${hostname}
          ];
        };

      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      nixosConfigurations = lib.mapAttrs mkHost hosts;

      # `nix fmt` formats every .nix file with the official formatter (RFC 166 style).
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
