# pi zero-2-w cross-compile config
This branch contains configuration specific for the Raspberry Pi Zero 2 W. 
Build this flake to create a NixOS SD card image based on NixOS unstable and
linux kernel version 6.6.5. USB host mode is enabled with the DTS patch.

Thanks to [Artemis Everfree's tutorial](https://artemis.sh/2023/06/06/cross-compile-nixos-for-great-good.html)
for helping me figure this out.

## Build instructions:
Ensure [Flakes are enabled](https://nixos.wiki/wiki/Flakes) on your system.
This flake will cross-compile an aarch64-linux system on an x86_64-linux system.

Clone this branch -
```
    git clone -b zero-2-w-native https://github.com/pete3n/nix-pi.git
```
Change to the root directory where the flake.nix file is located, then build with -
```
    nix build -L .#nixosConfigurations.images.zero2w
```
