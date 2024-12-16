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
    #settings.PermitRootLogin = lib.mkOverride 999 "yes";
  };

  services.qemuGuest.enable = true;

  #services.getty.autologinUser = lib.mkOverride 999 "root";

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  boot.initrd.systemd.enable = true;
  boot.growPartition = true;
  boot.kernelParams = [ "console=ttyS0" ];

  networking.networkmanager = {
      enable = true;
      plugins = lib.mkForce [ pkgs.networkmanager-fortisslvpn ];
  };

  # disable systemd-networkd
  systemd.network.enable = false;
  # disable networkd
  networking.useDHCP = false;

  environment.defaultPackages = with pkgs; [ cacert ];

  system = {
    switch = {
      enable = false;
      enableNg = true; # switch-to-configuration-ng
    };

    #etc.overlay.enable = true;
    #etc.overlay.mutable = true;
  };
}
