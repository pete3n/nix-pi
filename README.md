# pi zero-2-w native aarch64 built config
This branch contains configuration specific for the Raspberry Pi Zero 2 W. 
Build this flake to create a NixOS SD card image based on NixOS unstable and
linux kernel version 6.6.5. USB host mode is enabled with the DTS patch.

Thanks to [plmercereau's example](https://github.com/plmercereau/nixos-pi-zero-2)
flake that this was based on.

## Build instructions:
Ensure [Flakes are enabled](https://nixos.wiki/wiki/Flakes) on your system and that
your system can build aarch64-linux binaries.

Clone this branch -
```
    git clone -b zero-2-w-native https://github.com/pete3n/nix-pi.git
```
Change to the root directory where the flake.nix file is located, then build with -
```
    nix build -L .#nixosConfigurations.images.zero2w
```
