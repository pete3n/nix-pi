{
  description = "Flake for building a Raspberry Pi Zero 2 W SD image";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
    agenix.url = "github:ryantm/agenix";
    home-manager = {
        url = "github:nix-community/home-manager/release-23.11";
        inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, deploy-rs, agenix, ... }@inputs: 
    let
      inherit (self) outputs;
      flakePkgs = nixpkgs.legacyPackages.x86_64-linux;
      lib = flakePkgs.lib;

      systems = [
        "x86_64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in rec {
      nixosConfigurations.zero2w = flakePkgs.pkgsCross.aarch64-multiplatform.nixos {
        imports = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ./zero2w.nix
          agenix.nixosModules.default
        ];
        _module.args = { inherit inputs outputs; };
      };

      homeConfigurations.admin = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {inherit inputs outputs;};
        modules = [
          ./home-manager/home.nix
        ];
      };

      images.zero2w = nixosConfigurations.zero2w.config.system.build.sdImage; 

      deploy.nodes = {
        zero2w = {
          hostname = "nixos";
          profiles = {
            system = {
	      sshUser = "admin";
	      user = "root";
	      autoRollback = true;
	      magicRollback = true;
	      remoteBuild = false;
	      path = deploy-rs.lib.x86_64-linux.activate.nixos nixosConfigurations.robo-zero2w;
	      # Using x86_64 to allow pushing configs without NixOS and binfmt support
            };
            home = {
              sshUser = "admin";
              user = "admin";
              autoRollback = false;
              magicRollback = false;
              remoteBuild = false;
              path = deploy-rs.lib.x86_64-linux.activate.custom homeConfigurations.admin.activationPackage "./activate";
            };
          };
        };
      };
    };
}
