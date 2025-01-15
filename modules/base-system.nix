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

  services.getty.autologinUser = lib.mkOverride 999 "root";

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  boot.initrd.systemd.enable = true;
  boot.growPartition = true;

  boot.kernelParams = [ "console=ttyS0" ];

  # enable systemd-networkd
  systemd.network.enable = true;
  
  #systemd.sysusers.enable = true;
  #services.userborn.enable = false;

  networking.useNetworkd = true;
  # disable dhcpcd
  networking.useDHCP = false;

  # efibootmgr efivar
  environment.defaultPackages = with pkgs; [ cacert cloud-init ];
 
  system = {
     

    switch = {
      enable = false;
      enableNg = true; # switch-to-configuration-ng
    };

    #etc.overlay.enable = true;
    #etc.overlay.mutable = true;
  };
}
