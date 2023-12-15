{
  description = "Flake for building a Raspberry Pi Zero 2 SD image";

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
        hostname = "nixos";
        sshUser = "admin";
        autoRollback = true;
        magicRollback = true;
        remoteBuile = false;
        profiles.system = {
            user = "admin"; # Using x86_64 to allow pushing configs without NixOS and binfmt support
            path = deploy-rs.lib.x86_64-linux.activate.nixos nixosConfigurations.zero2w;
        };
      };

    };
}
