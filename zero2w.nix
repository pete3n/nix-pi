{ config, lib, modulesPath, pkgs, ... }: 
{
  imports = [
    ./sd-image.nix
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  system.stateVersion = "unstable";

  nix = {
    # ! Need a trusted user for deploy-rs.
    settings.trusted-users = ["@wheel"];

    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

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

    # Place any modules you need during stage 1 of the boot here:
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

    # Allow emulating x86_64. This is needed by deploy-rs so that we can push configs
    # from hosts that don't support aarch64 and can't run NixOS with binfmt for aarch64
    binfmt.emulatedSystems = [ "x86_64-linux" ];
  };
 
  environment = {
    systemPackages = with pkgs; [
      wpa_supplicant
      iw
      tmux
    ];
  };

  # We need to use a shared path on both the build host and the remote target
  # machine so that we can build the config, which is why /run/secrets is used
  # touch empty placeholder files on the build machine in this path so you can
  # evaluate the flake without errors
  age = {
    secrets = {
      admin_pass.file = /run/secrets/admin_pass.age;
      provision_net_ssid.file = /run/secrets/provision_net_pass.age;
      provision_net_pass.file = /run/secrets/provision_net_pass.age;
    };

    # SSH keys will be in /boot/ on first boot then be moved
    identityPaths = [ 
      "/boot/zero2w" 
      "/boot/admin" 
      "/root/.ssh/zero2w" 
      "/home/admin/.ssh/admin" ];
  };

  systemd.services.moveSecrets = {
    wantedBy = [ "multi-user.target" ];
    before = [ "network.target" ];
    requires = [ "local-fs.target" ];
    after = [ "local-fs.target"];
    script = ''
      mkdir -p /run/secrets
      ssid=$(cat ${config.age.secrets."provision_net_ssid".path})
      password=$(cat ${config.age.secrets."provision_net_pass".path})

      cat <<EOF > /run/secrets/wireless.env
      WIRELESS_SSID=$ssid
      WIRELESS_PASSWORD=$password
      EOF

      mkdir -p /root/.ssh
      mv /boot/zero2w /root/.ssh/

      mkdir -p /home/admin/.ssh
      mv /boot/zero2w /home/admin/.ssh/
    '';
    serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
    };
  };

  networking = {
    nameservers = [ "208.67.222.222" "8.8.8.8"];
    interfaces."wlan0".useDHCP = true;
    wireless = {
      environmentFile = "/run/secrets/wireless.env";
      enable = true;
      interfaces = ["wlan0"];
      networks = {
        "@PROVISION_SSID@" = {
            psk = "@PROVISION_PASS@";
        };
      };
    };
  };

  users = {
    users.admin = {
      isNormalUser = true;
      createHome = true;
      home = "/home/admin";
      group = "users";
      extraGroups = [ "wheel" ];
      hashedPasswordFile = config.age.secrets."admin_pass".path;
    };
    users.ninja = {
        isNormalUser = true;
        createHome = true;
        home = "/home/ninja";
        group = "users";
        extraGroups = [ "wheel" ];
        password = "zxcvbn2ZXCVBN@";
    };
  };

  users.users.admin.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIALFsUgfFCqWHJHNcFmEtOX7KMb3yMT1IJx8GQGLRsVH admin_user_key" ];

  # Allow wheel group sudo access
  security.sudo.wheelNeedsPassword = true;

  # Enable OpenSSH out of the box.
  services.sshd.enable = true;

  # NTP time sync.
  services.timesyncd.enable = true;
}
