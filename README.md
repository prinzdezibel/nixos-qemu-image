# Cross compile NixOS QEMU images

This flake allows to cross compile qcow images for QEMU. It's basically equivalent to nixos-generators' qow format,
but uses a modified nixpkgs repository with changes that allows make-disk-image to make usage of a fully fledged
QEMU qemu-system-x86_64 instance with TCG fallback instead of the qemu-kvm package which only supports emulation of
machines with the same CPU architecture.

# Steps

To cross compile nixos images for other architectures you have to configure boot.binfmt.emulatedSystems on your host system. For example, if your build machine's CPU architecture is ARM64 (aarch64) add this configuration to configuration.nix:
```
{
  # Enable binfmt emulation of x86_64-linux.
  boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
}
``` 

Configure QEMU's OVMF firmware in configuration.nix if you intend to run the image on your build machine's QEMU installation.
```
 libvirtd = {
    enable = true;
    qemu = {
      ovmf.enable = true;
      ovmf.packages = [
          pkgs.pkgsCross.gnu64.OVMF.fd # Intel
          pkgs.pkgsCross.aarch64-multiplatform.OVMF.fd # ARM
      ];
      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };
```

Specify your machine's system
```
buildSystem = "aarch64-linux"; # Change this if you're building on Intel arch
```

Build ARM based qcow image:
```
nix build .#nixosConfigurations.aarch64-linux.config.system.build.qcow
```

Build Intel based qcow image:
```
nix build .#nixosConfigurations.x86_64-linux.config.system.build.qcow
```

