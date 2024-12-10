# Cross compile NixOS QEMU cloud images

This flake allows to cross compile qcow images for QEMU. It's basically equivalent to nixos-generators' qow format,
but uses systemd-boot UEFI boot manager and a modified nixpkgs repository that allows make-disk-image to make usage of a fully fledged
QEMU qemu-system-x86_64 instance with TCG fallback instead of the qemu-kvm package which only supports machines with the same CPU architecture.

The image features cloud-init and is tested with shared and dedicated vCPUs at Hetzner Cloud. Please note that shared vCPUs hosts don't support systemd UEFI boot. For that to work you need to start the image in a dedicated vCPU and then change the bootloader to GRUB. After that you may create a snapshot of the machine which can be used for creating shared vCPU instances. Find more infos on how to do that below.


## Steps

To cross compile nixos images for other architectures you have to configure boot.binfmt.emulatedSystems on your host system. For example, if your build machine's CPU architecture is ARM64 (aarch64) put the following snippet into configuration.nix:
```
{
  # Enable binfmt emulation of x86_64-linux.
  boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
}
``` 

Configure QEMU's OVMF firmware in configuration.nix if you intend to run the image on your build machine's QEMU installation:
```
virtualisation.libvirtd = {
    enable = true;
    qemu = {
      ovmf.enable = true;
      ovmf.packages = [
          pkgs.pkgsCross.gnu64.OVMF.fd                 # Intel/AMD
          pkgs.pkgsCross.aarch64-multiplatform.OVMF.fd # ARM
      ];
      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };
```

Specify your machine's architecture in flake.nix:
```
buildSystem = "aarch64-linux"; # <-- Change this if you're building on Intel/AMD arch
```

Build ARM based qcow image:
```
nix build .#nixosConfigurations.aarch64-linux.config.system.build.qcow
```

Build Intel/AMD based qcow image:
```
nix build .#nixosConfigurations.x86_64-linux.config.system.build.qcow
```

Copy image to current directory:
```
cp result/nixos.qcow2 .
chmod 755 nixos.qcow2
```

ARM: Start qemu image in VM:
```
sudo qemu-system-aarch64 -enable-kvm -machine virt -cpu host -m 4G -smp 2 \
-drive cache=writeback,file=nixos.qcow2,id=drive1,if=none,index=1,werror=report \
-device virtio-blk-pci,drive=drive1 \
-drive if=pflash,format=raw,readonly=on,file=/run/libvirt/nix-ovmf/AAVMF_CODE.fd \
-smbios type=1,serial=ds=nocloud-net \
-nographic
```

Intel/AMD: Start qemu image in VM:
```
sudo qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -m 4G -smp 2 \
-drive cache=writeback,file=nixos.qcow2,id=drive1,if=none,index=1,werror=report \
-device virtio-blk-pci,drive=drive1 \
-drive if=pflash,format=raw,readonly=on,file=/run/libvirt/nix-ovmf/OVMF_CODE.fd \
-smbios type=1,serial=ds=nocloud-net \
-nographic
```


Add channel, update it and rebuild:
```
nix-channel --add https://nixos.org/channels/nixos-24.11 nixos
nixos-rebuild boot -I nixos-config=/etc/nixos/configuration.nix --upgrade
```



## Change boot loader to GRUB
```
cd /etc/nixos
mv configuration.nix configuration.nix.bak
mv modules/bootloader.nix modules/bootloader.nix.bak
mv modules/hardware-configuration.nix modules/hardware-configuration.nix.bak

echo "Build new hardware configuration with fileSystem info ..."
nixos-generate-config
sed -i "s/.\/hardware-configuration.nix/.\/hardware-configuration.nix\n      .\/modules\/base-system.nix\n     .\/modules\/cloud-init.nix/" configuration.nix
    
 echo "Change current EFI-only boot config to Grub-EFI"
 sed -i 's/# Use the systemd-boot EFI boot loader\.//' configuration.nix
 sed -i 's/boot.loader.systemd-boot.enable = true;/boot.loader.grub = { device = "\/dev\/sda"; enable = true; efiSupport = true; };\nboot.loader.systemd-boot.enable = false;/' configuration.nix

# For whatever reason the /boot filesystem is redundant and errors.
# See also: https://github.com/NixOS/nixpkgs/issues/283889
sed -zi 's/fileSystems."\/boot" =.*{.*}.*;//' hardware-configuration.nix
               
echo "Rebuild NixOs ..."
nixos-rebuild boot -I nixos-config=/etc/nixos/configuration.nix --upgrade
```
