
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
are running an x86_64-linux based system.

### Install qemu user static binaries

These are needed to emulate some of the tools in the build environment (pkg-config, protoc, protoc-c). 
On Debian based systems install with:
```
sudo apt -y install qemu-user-static
```
And then check that aarch64 is being emulated with:
```
ls -l /proc/sys/fs/binfmt_misc | grep aarch64
```

On NixOS add:
```
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
```
To your system config, and rebuild.


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
* agenix will use the SSH keys to encrypt the admin password hash and WiFi information
so the encrypted age files can be stored in a repo
* The age files are copied to a directory in /run so that Nix can copy them to the
nix store for the SD card image - NOTE: You can include files from relative paths with Nix
but they must be tracked by Git or they will be excluded and Nix will throw a confusing
error saying it cannot find them in the store
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
that would otherwise disconnect a remote system

## Configuration explanation
### flake.nix
```
  outputs = { self, nixpkgs, deploy-rs, agenix, ... }@inputs: 
    let
      flakePkgs = nixpkgs.legacyPackages.x86_64-linux;
    in rec {
      nixosConfigurations.zero2w = flakePkgs.pkgsCross.aarch64-multiplatform.nixos {
        imports = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ./zero2w.nix
          agenix.nixosModules.default
        ];
      };
      images.zero2w = nixosConfigurations.zero2w.config.system.build.sdImage; 
```

This is the key for cross-compiling. We need to use the pkgsCross package to build our
configuration for aarch64, however aarch64-multiplatform.nixos doesn't provide modules as
input so we use import for our configuration.

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

### zero2w.nix
```
boot = {
    # Use the 6.6.5 kernel and apply the usb host patch for the Zero 2 W
    # If you change kernels you must verify that the patch file is still valid
    # For the /arch/arm/boot/dts/broadcom/bcm2837-rpi-zero-2-w.dts file
    kernelPackages = let
	linux_zero2w_pkg = { fetchurl, buildLinux, ... }@ args:
	  buildLinux (args // rec {
	    version = "6.6.5";
	    modDirVersion = version;

	    src = fetchurl {
      		url = "https://mirrors.edge.kernel.org/pub/linux/kernel/v6.x/linux-${version}.tar.gz";
      		sha256 = "sha256-Q/DqpBwsuAfOH0Zy98aE9iH0PZbtqAvcOaOVxE2sxGc=";
	    };

	    kernelPatches = [
	      ({ 
	        name = "rpi-zero-2-w-usb-host";
            patch = ./patches/bcm2837-rpi-zero-2-w-usb-host.patch;
	      })
	    ];
	    
	  } // (args.argsOverride or {}));
    linux_zero2w = pkgs.callPackage linux_zero2w_pkg{};
      in
        pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor linux_zero2w);
```
This is the key to what make this config different than all the other Pi Zero 2 W
configs and images. The default kernel built for the Zero 2 W will create a broadcom
DTB which sets the USB controller to OTG mode for DWC2. This will prevent any USB
connected accessories (hubs, keyboards, wifi, cell modems, etc.) from working. This
build applies the following source patch:
```
--- a/arch/arm/boot/dts/broadcom/bcm2837-rpi-zero-2-w.dts       2023-12-10 06:59:12.362323142 +0000
+++ b/arch/arm/boot/dts/broadcom/bcm2837-rpi-zero-2-w.dts       2023-12-11 12:26:35.668693854 +0000
@@ -6,7 +6,7 @@
 /dts-v1/;
 #include "bcm2837.dtsi"
 #include "bcm2836-rpi.dtsi"
 #include "bcm283x-rpi-led-deprecated.dtsi"
-#include "bcm283x-rpi-usb-otg.dtsi"
+#include "bcm283x-rpi-usb-host.dtsi"
 #include "bcm283x-rpi-wifi-bt.dtsi"

 / {
```
which will build the DTB in USB host mode. It may also be possible to achieve this with an
overlay, but it seems like there were mixed results online, and this is guaranteed to work.

```
age = {
    secrets = {
      admin_pass.file = /run/zero2w-build-secrets/admin_pass.age;
      provision_net_ssid.file = /run/zero2w-build-secrets/provision_net_ssid.age;
      provision_net_pass.file = /run/zero2w-build-secrets/provision_net_pass.age;
    };

    # SSH keys will be in /boot/ on first boot, and then moved by the activation script
    # Those paths should be removed after initial configuration
    identityPaths = [ 
      "/boot/zero2w" 
      "/boot/admin" 
      "/root/.ssh/zero2w" 
      "/home/admin/.ssh/admin" ];
  };
```
I use agenix to encrypted the secrets. They need to be in an absolute path on the build
system for Nix to included them when building the store. Either /run or /tmp make sense
for this. 
* NOTE: If these files are missing during building, deploying, or checking the config
Nix will throw an error saying it cannot find the age files.
* The /root and /home directories don't exist until the SD card it booted into Nix, so
the SSH keys are copied to /boot on the SD card and then moved during bootup

```
system.activationScripts.moveSecrets = {
    text = ''
      mkdir -p /etc/wpa_supplicant
      ssid=$(cat ${config.age.secrets."provision_net_ssid".path})
      password=$(cat ${config.age.secrets."provision_net_pass".path})

      cat <<EOF > /etc/wpa_supplicant/wireless.env
      PROVISION_NET_SSID=$ssid
      PROVISION_NET_PASS=$password
      EOF

      if [ -f /boot/zero2w ]; then
        mkdir -p /root/.ssh
        mv /boot/zero2w /root/.ssh/
      fi

      if [ -f /boot/admin ]; then
        mkdir -p /home/admin/.ssh
        mv /boot/admin /himpme/admin/.ssh/
      fi
    '';
  };
```
The activation script moves the SSH keys and creates the wireless.env file on bootup

```
networking = {
    nameservers = [ "208.67.222.222" "8.8.8.8"];
    interfaces."wlan0".useDHCP = true;
    wireless = {
      environmentFile = "/etc/wpa_supplicant/wireless.env";
      enable = true;
      interfaces = [ "wlan0" ];
      networks = {
        "@PROVISION_NET_SSID@" = {
            psk = "@PROVISION_NET_PASS@";
        };
      };
    };
  };

```
I referenced the variables in the wireless.env file for the SSID and password because
I couldn't find a good way to read them from the age config path, which is a file.

```
  users = {
    users.admin = {
      isNormalUser = true;
      createHome = true;
      home = "/home/admin";
      group = "users";
      extraGroups = [ "wheel" ];
      hashedPasswordFile = config.age.secrets."admin_pass".path;
    };
  };

  users.users.admin.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG7r8TkS19MbBIWg2b/GCFI343zTp/UPt7Wno0sJhv4s admin_user_key" ];
```
The user config has a hashedPasswordFile property which accepts a file as input, so
I can directly reference the age.secrets path here.

The authorizedKeys.key is added by the build script which copies over the public key
from the admin user to here.

