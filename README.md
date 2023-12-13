# pi zero-2-w config
This branch contains configuration specific for the Raspberry Pi Zero 2 W. 
Build this flake to create a NixOS SD card image based on NixOS unstable and
linux kernel version 6.6.5. USB host mode is enabled with the DTS patch.

Thanks to [plmercereau's example](https://github.com/plmercereau/nixos-pi-zero-2)
flake that this was based on.

## Build instructions:
This flake needs a native aarch64-linux system to build on.

Clone this branch -
```
    git clone -b zero-2-w-native https://github.com/pete3n/nix-pi.git
```
Ensure [Flakes are enabled](https://nixos.wiki/wiki/Flakes) on your system,
then build with -
```
    nix build -L .#nixosConfigurations.images.zero2w
```
