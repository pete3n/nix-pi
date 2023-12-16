{
  description = "Flake for building a Raspberry Pi Zero 2 W SD image";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
    agenix.url = "github:ryantm/agenix";
  };

  outputs = { self, nixpkgs, deploy-rs, agenix, ... }@inputs: 
    let
      nonFlakePkgs = nixpkgs.legacyPackages.x86_64-linux;
    in rec {
      nixosConfigurations.zero2w = nonFlakePkgs.pkgsCross.aarch64-multiplatform.nixos {
        imports = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ./zero2w.nix
          agenix.nixosModules.default
        ];
      };
      images.zero2w = nixosConfigurations.zero2w.config.system.build.sdImage; 

      deploy.nodes.zero2w = {
        hostname = "nixos-zero2w";
        profiles.system = {
            sshUser = "admin";
            user = "root"; 
            autoRollback = true;
            magicRollback = true;
            remoteBuild = false;
            path = deploy-rs.lib.x86_64-linux.activate.nixos nixosConfigurations.zero2w;
            # Using x86_64 to allow pushing configs from hosts without NixOS and binfmt aarch64 support
        };
      };
    };
}
