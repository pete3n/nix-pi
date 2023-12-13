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
#            ({ pkgs, ... }: {
#                nixpkgs.overlays = [
#                  (final: super: {
#                    makeModulesClosure = x:
#                      super.makeModulesClosure (x // { allowMissing = true; });
#                  })
#                ];
#            })
          ];
       };
      images.zero2w = nixosConfigurations.zero2.config.system.build.sdImage; 
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
