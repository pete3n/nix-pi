{
  description = "Flake for building a Raspberry Pi Zero 2 W SD image";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
    agenix.url = "github:ryantm/agenix";
  };

  outputs = { self, nixpkgs, deploy-rs, agenix }: rec {
    nixosConfigurations = {
      zero2w = nixpkgs.lib.nixosSystem {
          modules = [
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            ./zero2w.nix
            agenix.nixosModules.default
          ];
       };
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
        path = deploy-rs.lib.aarch64-linux.activate.nixos self.nixosConfigurations.zero2w;
      };
    };
  };
}
