{
  description = "Flake for building a Raspberry Pi Zero 2 SD image";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = { self, nixpkgs, deploy-rs }: 
    let
      nonFlakePkgs = nixpkgs.legacyPackages.x86_64-linux;
    in rec {
      nixosConfigurations.zero2w = nonFlakePkgs.pkgsCross.aarch64-multiplatform.nixos {
        imports = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ./zero2w.nix
        ];
      };
      images.zero2w = nixosConfigurations.zero2w.config.system.build.sdImage; 

      deploy = {
        user = "admin";
        nodes = {
          zero2w = {
            hostname = "nixos";
            profiles.system.path =
            deploy-rs.lib.aarch64-linux.activate.nixos self.nixosConfigurations.zero2w;
          };
        };
      };
  };
}
