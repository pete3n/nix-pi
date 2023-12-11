# pi zero-2-w config
This branch contains configuration specific for the Raspberry Pi Zero 2 W. 
Build this flake to create a NixOS SD card image based on NixOS unstable and
linux kernel version 6.6.5. USB host mode is enabled with the DTS patch.

## Build with:
nix build -L .#nixosConfiguration.zerow2w.config.system.build.sdImage
