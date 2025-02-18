{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    "${toString modulesPath}/profiles/qemu-guest.nix"
  ];

  # no graphical stuff
  xdg.autostart.enable = lib.mkDefault false;
  xdg.icons.enable = lib.mkDefault false;
  xdg.mime.enable = lib.mkDefault false;
  xdg.sounds.enable = lib.mkDefault false;

  networking.firewall.enable = false;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PubkeyAuthentication = true;
  };

  services.qemuGuest.enable = true;

  #services.getty.autologinUser = lib.mkOverride 999 "root";

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  boot = {
    initrd.systemd.enable = true;
    # Set to true for unauthenticated emergency access in case of boot failure
    initrd.systemd.emergencyAccess = false;
     
    growPartition = true;
    kernelParams = [ "console=ttyS0" ];
    # Use the systemd-boot EFI boot loader.
    loader.systemd-boot.enable = true;
    loader.systemd-boot.configurationLimit = 5;
    loader.timeout = 0; # Timeout does not work and seems to conflict with Clover timeout
    #loader.systemd-boot.edk2-uefi-shell.enable = false;
    #loader.systemd-boot.editor = false;
    loader.efi = {
      canTouchEfiVariables = if pkgs.system != "x86_64-linux" then true else false;
    };
  };

  # enable systemd-networkd
  systemd.network.enable = true;

  #systemd.sysusers.enable = true;
  #services.userborn.enable = false;

  networking.useNetworkd = true;
  # disable dhcpcd
  networking.useDHCP = false;

  environment.defaultPackages = with pkgs; [
    cacert
    cloud-init
  ];

  system = {
    switch = {
      enable = false;
      enableNg = true; # switch-to-configuration-ng
    };

    #etc.overlay.enable = true;
    #etc.overlay.mutable = true;
  };
}
