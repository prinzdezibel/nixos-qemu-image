{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  # The lessopen package pulls in Perl.
  programs.less.lessopen = lib.mkDefault null;

  #  DBus service that allows applications to query and manipulate storage devices
  services.udisks2.enable = lib.mkDefault false;

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
    settings.PermitRootLogin = lib.mkOverride 999 "yes";
  };

  services.qemuGuest.enable = true;

  services.getty.autologinUser = lib.mkOverride 999 "root";

  system = {
    switch = {
      enable = false;
      enableNg = true; # switch-to-configuration-ng
    };
  };
}
