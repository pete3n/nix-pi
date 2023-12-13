{
  description = "Flake for building a Raspberry Pi Zero 2 SD image";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = { self, nixpkgs, deploy-rs }: rec {
    nixosConfigurations = {
      zero2w = nixpkgs.lib.nixosSystem {
          modules = [
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            ./zero2w.nix
          ];
       };
      images.zero2w = nixosConfigurations.zero2w.config.system.build.sdImage; 

      # Build the image by default with nix build
      packages.aarch64-linux.default = self.images.zero2w;
      defaultPackage.aarch64-linux = self.packages.aarch64-linux.default;
    };

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
