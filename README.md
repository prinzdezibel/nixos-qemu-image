# (Cross-) compile NixOS QEMU cloud images

This flake allows to cross compile qcow images for QEMU. Of course compiling for the same CPU platform is supported as well. It's basically equivalent to nixos-generators' qow format, but uses systemd-boot UEFI boot manager and a modified nixpkgs repository that allows make-disk-image to make usage of a fully fledged QEMU qemu-system-x86_64 instance with TCG fallback instead of the qemu-kvm package which only supports machines with the same CPU architecture.

The image features cloud-init and is tested with shared and dedicated vCPUs at Hetzner Cloud. Please note that shared vCPUs hosts don't support systemd UEFI boot. For that to work you need to ensure the emulatedUEFI option is set to true (which is the default). This will install the Clover bootloader which is able to emulate UEFI environments on legacy BIOS systems. Once Clover is loaded it will acts as chainloader for regular systemd-boot. If your system is already UEFI enabled, you may set the option emulatedUEFI to false in [flake.nix](https://github.com/prinzdezibel/nixos-qemu-image/blob/d4789fc12b58d0ac8593d961dfe49427d508e7df/flake.nix#L41).

## Supported platforms
x86_64-linux and aarch64-linux

## Steps


Configure QEMU's OVMF firmware in your system's configuration.nix if you intend to run the image on your build machine's QEMU installation:
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

Specify your machine's architecture in [flake.nix](https://github.com/prinzdezibel/nixos-qemu-image/blob/d4789fc12b58d0ac8593d961dfe49427d508e7df/flake.nix#L16):
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

ARM + UEFI: Start qemu image in VM:
```
sudo qemu-system-aarch64 -enable-kvm -machine virt -cpu host -m 4G -smp 2 \
-drive cache=writeback,file=nixos.qcow2,id=drive1,if=none,index=1,werror=report \
-device virtio-blk-pci,drive=drive1 \
-drive if=pflash,format=raw,readonly=on,file=/run/libvirt/nix-ovmf/AAVMF_CODE.fd \
-smbios type=1,serial=ds=nocloud-net \
-nographic
```

Intel/AMD + UEFI: Start qemu image in VM:
```
sudo qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -m 4G -smp 2 \
-drive cache=writeback,file=nixos.qcow2,id=drive1,if=none,index=1,werror=report \
-device virtio-blk-pci,drive=drive1 \
-drive if=pflash,format=raw,readonly=on,file=/run/libvirt/nix-ovmf/OVMF_CODE.fd \
-smbios type=1,serial=ds=nocloud-net \
-nographic
```

Intel/AMD + BIOS: Start qemu image in VM:
```
sudo qemu-system-x86_64 -machine q35 -m 4G -smp 2 \
-drive file=nixos.qcow2,werror=report \
-smbios type=1,serial=ds=nocloud-net
```

Add channel, update it and rebuild:
```
nix-channel --add https://nixos.org/channels/nixos-24.11 nixos
nixos-rebuild boot -I nixos-config=/etc/nixos/configuration.nix --upgrade
```

## Convert image for usage in cloud environment (tested with Hetzner)
```
 qemu-img convert -p -f qcow2 -O host_device nixos.qcow2 /dev/sda
```
