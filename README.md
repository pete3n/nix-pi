
# pi-nix zero-2-w cross-compile branch
This branch contains a NixOS configuration specific for the Raspberry Pi Zero 2 W. 
The flake in this repo contains build targets for an SD card image based on NixOS unstable 
and linux kernel version 6.6.5. USB host mode is enabled with a patch for the
zero2w DTS source.

Thanks to [plmercereau's example](https://github.com/plmercereau/nixos-pi-zero-2)
showing how to build an SD image for the Pi 2 Zero, and to [Artemis Everfree's tutorial](https://artemis.sh/2023/06/06/cross-compile-nixos-for-great-good.html)
for helping me figure out how to cross-compile on systems using only Nix. While it is 
possible to build aarch64-linux targets on x86_64-linux NixOS with QEMU and the binfmt 
setting, this is the only method I have found that allows building aarch64 targets on 
x86_64-linux systems not running NixOS.

## Build instructions:
Ensure [Flakes are enabled](https://nixos.wiki/wiki/Flakes) for Nix, and that you 
are running an x86_64-linux bases system.

Clone this branch with:
```
git clone -b zero-2-w-cross https://github.com/pete3n/nix-pi.git
```
Change to the nix-pi directory.

You can build a new image with:
```
sudo ./build_new_sd.sh
```

This script will walk you through configuration options for a new SD card image:
* The provisioning network will be the WiFi network the Pi will automatically
connect to on boot to provide SSH access
* The admin password is set for the admin user which will have sudo privileges
* SSH keys for the admin user and system will be generated
* agenix will use the SSH keys tou encrypt the admin password hash and WiFi information
so the encrypted age files can be stored in a repo
* The age files are copied to a directory in /run so that Nix can copy them to the
nix store for the SD card image
* The SD card image is mounted temporarily so that the private SSH keys can be copied
* The public/private SSH key pairs will be saved to ./private
* The final SD card image will be saved to ./output

If you want to modify an existing SD card configuration:
```
sudo ./rebuild_sd.sh
```
Allows you to rebuild the configuration and create a new SD image, but re-use the same
SSH keys, Wifi config, and admin password.

If you need to push configuration changes to an online system, you can use:
```
sudo ./deploy_config.sh
```
Which uses [deploy-rs](https://github.com/serokell/deploy-rs) to build a new config
on your local machine and then deploy it to the pi. This has several benefits:
1. The pi zero 2 w will usually run out of RAM and crash when attempting to rebuild
a system config for itself
2. deploy-rs has several safety mechanisms which can rollback system breaking configs
which would otherwise disconnect a remote system

## Configuration explanation
### flake.nix
```
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
```

This is the key for cross-compiling. We need to use the pkgsCross package to build our
configuration for aarch64, however that is found in legacyPackages which don't support
flakes (do my understanding). aarch64-multiplatform.nixos doesn't utilize modules as
input so we import our configuration.

```
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
```
* hostname = "nixos-zero2w" is arbitrary because we will manually specifiy the hostname 
for the deployment script, but it has to be included or deploy-rs will invalidate the config.
* user must be root to force deploy-rs to use sudo privileges when deploying the configuration
otherwise the switch-to-configuration script will have permission errors
* using deploy-rs.lib.x86_64-linux allows us to execute natively on our x86_64-linux platform
but will require the target Pi to be able to emulate x86_64
