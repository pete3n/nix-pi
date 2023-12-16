# pi zero-2-w cross-compile config
This branch contains a NixOS configuration specific for the Raspberry Pi Zero 2 W. 
The flake in this repo contains build targets for an SD card image based on NixOS unstable 
and linux kernel version 6.6.5. USB host mode is enabled with a patch for the
zero2w DTS source.

Thanks to [Artemis Everfree's tutorial](https://artemis.sh/2023/06/06/cross-compile-nixos-for-great-good.html)
for helping me figure out how to cross-compile on systems using only Nix. It is possible
emulated system architectures on NixOS with QEMU and the binfmt setting, however this
is the only method I have found that allows building aarch64 targets on x86_64
systems not running NixOS.

## Build instructions:
Ensure [Flakes are enabled](https://nixos.wiki/wiki/Flakes) for Nix, and that you 
are running an x86_64-linux bases system.

Clone this branch with:
```
git clone -b zero-2-w-cross https://github.com/pete3n/nix-pi.git
```
Change to the root directory where the flake.nix file is located.

You can build a new image with:
```
sudo ./build_new_sd.sh
```

This script will walk you through configuration options for a new SD card image:
* The provisioning network will be the WiFi network the Pi will automatically
connect to on boot to provide SSH access
* The admin password is set for the admin user which will have sudo privileges
* SSH keys for the admin user and system will be generated
* agenix will use the SSH keys to encrypt the admin password hash and WiFi information
so the encrypted age files can be stored in a repo
* The age files are copied to a directory in run so that Nix can copy them to the
nix store for the SD card image
* The SD card image is mounted temporarily so that the private SSH keys can be copied

