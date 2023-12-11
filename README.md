# pi zero-2-w config
This branch contains configuration specific for the Raspberry Pi Zero 2 W. 
Build this flake to create a NixOS SD card image based on NixOS unstable and
linux kernel version 6.6.5. USB host mode is enabled with the DTS patch.

## Build instructions:
Clone this branch -
```
    git clone -b zero-2-w https://github.com/pete3n/nix-pi.git
```
Ensure flakes are enabled and that you can build aarch64 binaries on your system
Then build with -
```
    nix build -L .#nixosConfiguration.zero2w.config.system.build.sdImage
```
