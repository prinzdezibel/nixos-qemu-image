{ pkgs, lib, ... }:
{
  boot.loader = {
    systemd-boot.enable = true;
    efi = {
      canTouchEfiVariables = true;
    };
    grub.enable = false;

    grub.device =
      if (pkgs.system == "x86_64-linux") then (lib.mkDefault "/dev/vda") else (lib.mkDefault "nodev");

    grub.efiSupport = lib.mkIf (pkgs.system != "x86_64-linux") (lib.mkDefault true);
    grub.efiInstallAsRemovable = lib.mkIf (pkgs.system != "x86_64-linux") (lib.mkDefault true);
    timeout = 5;
  };
}
