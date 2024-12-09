{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  base = "/etc/nixpkgs/channels";
  nixpkgsPath = "${base}/nixpkgs";
in
{
  imports = [
    "${toString modulesPath}/profiles/qemu-guest.nix"
  ];

  #environment.systemPackages = [ pkgs.nixos-install-tools ];

  # documentation.nixos depends on Perl. Disable it.
  #documentation.nixos.enable = lib.mkDefault false;

  # Perl is a default package and can't be cross-compiled. Remove it.
  #environment.defaultPackages = lib.mkDefault [ ];

  # The lessopen package pulls in Perl.
  #programs.less.lessopen = lib.mkDefault null;

  # DBus service that allows applications to query and manipulate storage devices
  # services.udisks2.enable = lib.mkDefault false;

  # no graphical stuff
  xdg.autostart.enable = lib.mkDefault false;
  xdg.icons.enable = lib.mkDefault false;
  xdg.mime.enable = lib.mkDefault false;
  xdg.sounds.enable = lib.mkDefault false;

  networking.firewall.enable = false;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PubkeyAuthentication = true;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = lib.mkOverride 999 "yes";
    #settings.PermitRootLogin = lib.mkOverride 999 "prohibit-password";
  };

  services.qemuGuest.enable = true;

  services.getty.autologinUser = lib.mkOverride 999 "root";

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    #   nixPath = [
    #     "nixpkgs=${nixpkgsPath}"
    #     "/nix/var/nix/profiles/per-user/root/channels"
    #   ];
  };

  boot.initrd.systemd.enable = true;
  boot.growPartition = true;
  boot.kernelParams = [ "console=ttyS0" ];

  networking.useDHCP = false;

  networking.networkmanager = {
      enable = true;
      plugins = lib.mkForce [ pkgs.networkmanager-fortisslvpn ];
  };

  # systemd.network = {
  #   enable = true;
  #   networks."10-wan" = {
  #     # Main network interface MAC
  #     #matchConfig.MACAddress = "12:34:56:78:9a:b";
  #     matchConfig.Name = "enp1s0"; # either ens3 or enp1s0 depending on system, check 'ip addr'
  #     networkConfig.DHCP = "ipv4";
  #     # address = [
  #     #   # replace this address with the one assigned to your instance
  #     #   "2a01:4f8:aaaa:bbbb::1/64"
  #     # ];
  #     # routes = [
  #     #   { routeConfig.Gateway = "fe80::1"; }
  #     # ];
  #   };
  #    networks."20-wan" = {
  #     matchConfig.Name = "ens3"; # either ens3 or enp1s0 depending on system, check 'ip addr'
  #     networkConfig.DHCP = "ipv4";
  #   };
  # };

  system = {
    switch = {
      enable = false;
      enableNg = true; # switch-to-configuration-ng
    };

    etc.overlay.enable = true;
    etc.overlay.mutable = true;
  };
}
