{ lib, modulesPath, pkgs, ... }: 
{
  imports = [
    ./sd-image.nix
  ];

  system.stateVersion = "unstable";

  nixpkgs.hostPlatform = "aarch64-linux";

  # ! Need a trusted user for deploy-rs.
  nix.settings.trusted-users = ["@wheel"];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
  };

  sdImage = {
    # bzip2 compression takes loads of time with emulation, skip it. Enable this if you're low on space.
    compressImage = false;
    imageName = "zero2w-nixos-k6.6.5.img";

    extraFirmwareConfig = {
      # Give up VRAM for more Free System Memory
      # - Disable camera which automatically reserves 128MB VRAM
      start_x = 0;
      # - Reduce allocation of VRAM to 16MB minimum for non-rotated (32MB for rotated)
      gpu_mem = 16;

      # Configure display to 800x600 so it fits on most screens
      # * See: https://elinux.org/RPi_Configuration
      #hdmi_group = 2;
      #hdmi_mode = 8;
    };
  };

  # Keep this to make sure wifi works
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.firmware = [
    pkgs.raspberrypiWirelessFirmware
  ];

  #environment.noXlibs = lib.mkForce false;

  boot = {
    # Use the 6.6.5 kernel and apply the usb host patch for the Zero 2 W
    # If you change kernels you must verify that the patch file is still valid
    # For the /arch/arm/boot/dts/broadcom/bcm2837-rpi-zero-2-w.dts file
    kernelPackages = let
	linux_zero2w_pkg = { fetchurl, buildLinux, ... } @ args:
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
            patch = ./bcm2837-rpi-zero-2-w-usb-host.patch;
	      })
	    ];
	    
	  } // (args.argsOverride or {}));
    linux_zero2w = pkgs.callPackage linux_zero2w_pkg{};
      in
        pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor linux_zero2w);

    # Place any modules you need during stage 1 of the boot here
    #initrd.availableKernelModules = [
    #  "ehci_hcd" 
    #  "usbhid" 
    #  "usb_storage"
    #];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };

    # Don't build ZFS unless we need it, because it takes forever
    supportedFilesystems = lib.mkForce [ "btrfs" "cifs" "f2fs" "nfs" "jfs" "ntfs" "reiserfs" "vfat" ];

    # Avoids warning: mdadm: Neither MAILADDR nor PROGRAM has been set. This will cause the `mdmon` service to crash.
    # See: https://github.com/NixOS/nixpkgs/issues/254807
    swraid.enable = lib.mkForce false;
  };
 
  environment = {
    systemPackages = with pkgs; [
      wpa_supplicant
      iw
      tmux
    ];
  };

  networking = {
    nameservers = [ "208.67.222.222" "8.8.8.8"];
    interfaces."wlan0".useDHCP = true;
    wireless = {
      enable = true;
      interfaces = ["wlan0"];
      networks = {
        "config-net-ssid" = {
          psk = "config-net-password";
        };
      };
    };
  };

  # Enable OpenSSH out of the box.
  services.sshd.enable = true;

  # NTP time sync.
  services.timesyncd.enable = true;
}
