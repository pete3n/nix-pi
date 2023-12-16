# nix-pi

This repo contains [NixOS](https://nixos.org/manual/nixos/stable/) 
[Flakes](https://nixos.wiki/wiki/Flakes) to build system images for the Raspberry Pi.

The repo is organized into branches based on the target model Pi and the build platform.
Currently it contains custom configs for the Pi Zero 2 W.

* If you are building on an aarch64-linux system: [use the native branch](https://github.com/pete3n/nix-pi/tree/zero-2-w-native)

* If you are building on an x86_64-linux system: [use the cross compile branch](https://github.com/pete3n/nix-pi/tree/zero-2-w-cross)

## Getting Started with Nix
These flakes can be built with the Nix package manager and do not require a full NixOS 
system installation. [Follow these instrutions](https://nixos.org/download#download-nix)
 to download and install the Nix package manager for your system. I have only tested 
these builds on Debian 11, Ubuntu 22.04,  and NixOS 23.11 so far, but they should theoretically work on
any x86_64-linux compatible system running the Nix package manager. 

Once you have the package manager installed, add the following line to ~/.config/nix/nix.conf
or /etc/nix/nix.conf , if neither file exists, then create one, and add:
```
experimental-features = nix-command flakes
```
You will need to restart your shell or terminal session for it to take effect.
