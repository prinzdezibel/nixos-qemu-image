{ pkgs, config, lib, ... }:
let
  cloverCompressed = pkgs.fetchurl {
    url = "https://github.com/CloverHackyColor/CloverBootloader/releases/download/5161/Clover-5161-X64.iso.7z";
    hash = "sha256-CL3F87T0b+ReAkPIZYDAfRSGsxEKzlHjrHVACHiu1ks=";
  };
in
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
  };

  boot.loader = {
    timeout = 5;
    systemd-boot = {
      enable = true;
      configurationLimit = 5;
      extraInstallCommands = lib.mkIf (config.emulatedUEFI && pkgs.system == "x86_64-linux") ''
        set -euo pipefail

        echo "Install CloverBootloader..." 

        ${pkgs.p7zip}/bin/7z e ${cloverCompressed} -o/tmp
        
        IMAGE=$(ls -a /tmp | grep -ie '^Clover-.*-X64.iso$')
        DEVICE=$(losetup -f)
        mkdir -p /tmp/iso

        losetup $DEVICE /tmp/$IMAGE
        mount -o ro $DEVICE /tmp/iso

        # MBR
        dd if=/tmp/iso/usr/standalone/i386/boot0ss of=/dev/vda bs=440 count=1 conv=notrunc
        
        # Merge Clover code with current Partition Boot Records (PBR)
        dd if=/dev/vda1 bs=512 count=1 of=/tmp/original_PBR
        cp /tmp/iso/usr/standalone/i386/boot1f32 /tmp/new_PBR
        dd if=/tmp/original_PBR of=/tmp/new_PBR skip=3 seek=3 bs=1 count=87 conv=notrunc
        dd if=/tmp/new_PBR of=/dev/vda1 bs=512 count=1
        
        # Copy the legacy bootloader to the EFI system partition:
        cp /tmp/iso/usr/standalone/i386/x64/boot6 /boot/boot

        # Copy Clover EFI files
        cp -R /tmp/iso/efi/clover /boot/EFI/

        cp /boot/EFI/CLOVER/cloverx64.efi /boot/EFI/BOOT/BOOTX64.EFI
        
        # Chainload systemd-boot
        cat <<-EOF > /boot/EFI/CLOVER/config.plist
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
          <dict>
            <key>Boot</key>
            <dict>
              <key>Timeout</key>
              <integer>4</integer>
              <key>DefaultVolume</key>
              <string>FirstAvailable</string>
              <key>DefaultLoader</key>
              <string>\EFI\systemd\systemd-bootx64.efi</string>
            	<key>Fast</key>
		          <false/>
              <key>Debug</key>
              <true/>
            </dict>
            <key>GUI</key>
            <dict>
              <key>TextOnly</key>
              <true/>
              <key>Custom</key>
              <dict>
                <key>Entries</key>
                <array>
                  <dict>
                    <key>Hidden</key>
                    <false/>
                    <key>Disabled</key>
                    <false/>
                    <key>Image</key>
                    <string>os_arch</string>
                    <key>Volume</key>
                    <string>ESP</string>
                    <key>Path</key>
                    <string>\EFI\systemd\systemd-bootx64.efi</string>
                    <key>Title</key>
                    <string>NixOS Linux</string>
                    <key>Type</key>
                    <string>Linux</string>
                  </dict>
                </array>
              </dict>
            </dict>
          </dict>
        </plist>
EOF

        umount /tmp/iso
        losetup -d $DEVICE          

        # set dummy partition active/bootable in protective MBR to give some too
        # smart BIOS the clue that this disk can be booted in legacy mode
        echo "Setting the active flag on the protective MBR partition..."
        ${pkgs.util-linux}/bin/sfdisk --activate /dev/vda 1 --force
        ${pkgs.parted}/bin/partprobe
      '';
    };
    efi = {
      # Set true if system is UEFI-enabled. Conflicts with grub.efiInstallAsRemovable = true
      canTouchEfiVariables = if pkgs.system != "x86_64-linux" then true else false;
    };

    # Cross-Compiling GRUB results in an error because of Perl dependency:
    # Can't locate XML/SAX.pm in @INC (you may need to install the XML::SAX module) 
    #grub.enable = true;
    #grub.device = "/dev/vda"; # when using GRUB in a BIOS/GPT setup
    ##grub.device = "nodev"; # when using UEFI-enabled system.
    #
    ### GRUB should load from ESP, even if system is not natively UEFI-enabled and GRUB is using a BIOS/GPT setup
    #grub.efiSupport = true;
    #grub.efiInstallAsRemovable = if pkgs.system != "x86_64-linux" then false else true; # in case canTouchEfiVariables doesn't work for your system. Check with efibootmgr. See https://docs.hetzner.com/robot/dedicated-server/operating-systems/uefi/#using-efibootmgr

  };
}
