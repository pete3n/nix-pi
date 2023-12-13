# nix-pi

This repo contains [NixOS](https://nixos.org/manual/nixos/stable/) 
[Flakes](https://nixos.wiki/wiki/Flakes) to build system images for the Raspberry Pi.

The repo is organized into branches based on the target model Pi and the build platform.
The main branch contains common to all files, while the -native branches build on ARM
based systems, and the -cross branches build on x86_64-linux systems.
