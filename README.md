# nix-pi

This repo contains [NixOS](https://nixos.org/manual/nixos/stable/) 
[Flakes](https://nixos.wiki/wiki/Flakes) to build system images for the Raspberry Pi.

This repo is organized into branches based on the target model pi and the build platform.
The main branch contains common to all files, native branches are mean to be built on ARM
based systems, the cross branches are meant to be built on x86_64-linux machines.
