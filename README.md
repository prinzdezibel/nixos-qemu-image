# (Cross-) compile NixOS QEMU cloud images

This flake allows to cross compile qcow images for QEMU. Of course compiling for the same CPU platform is supported as well. It's basically equivalent to nixos-generators' qow format, but uses systemd-boot UEFI boot manager and a modified nixpkgs repository that allows make-disk-image to make usage of a fully fledged QEMU qemu-system-x86_64 instance with TCG fallback instead of the qemu-kvm package which only supports machines with the same CPU architecture.

The image features cloud-init and is tested with shared and dedicated vCPUs at Hetzner Cloud. Please note that shared vCPUs hosts don't support systemd UEFI boot. For that to work you need to ensure the emulatedUEFI option is set to true (which is the default). This will install the Clover bootloader which is able to emulate UEFI environments on legacy BIOS systems. Once Clover is loaded it will acts as chainloader for regular systemd-boot. If your system is already UEFI enabled, you may set the option emulatedUEFI to false in [flake.nix](https://github.com/prinzdezibel/nixos-qemu-image/blob/9dde1872fb0bdf8136a022ff7890642ec0056167/flake.nix#L54).

## Supported platforms
x86_64-linux and aarch64-linux

## Steps

To cross compile nixos images for other architectures you have to configure boot.binfmt.emulatedSystems on your host system. For example, if your build machine's CPU architecture is ARM64 (aarch64) put the following snippet into configuration.nix:
```
{
  # Enable binfmt emulation of x86_64-linux.
  boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
  nix.settings.extra-platforms = [ "x86_64-linux" ];
}
``` 

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

Specify your machine's architecture in [flake.nix](https://github.com/prinzdezibel/nixos-qemu-image/blob/9dde1872fb0bdf8136a022ff7890642ec0056167/flake.nix#L16):
```
buildSystem = "aarch64-linux"; # <-- Change this if you're building on Intel/AMD arch
```

Build ARM based qcow image:
```
nix build .#nixosConfigurations.aarch64-linux.qcow
```

Build Intel/AMD based qcow image:
```
nix build .#nixosConfigurations.x86_64-linux.qcow
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

## Troubleshooting

In case you see an error similar to this
```
qemu-x86_64: /nix/store/razasrvdg7ckplfmvdxv4ia3wbayr94s-bootstrap-tools/bin/bash: Unable to find a guest_base to satisfy all guest address mapping requirements 0000000000000000-0000000000000fff 00000000003ff000-00000000004e22ef
```
I believe the reason is that QEMU somehow is not able to figure out where the  dynamic linking loader is located that is needed in early bootstrap phase. I didn't have luck with specifiying QEMU's 
QEMU_LD_PREFIX environment variable either. The only thing that fixed the problem for me was to overlay the binfmt binary in the host's configuration.nix
and load the emulated binaries through it's dynamic linking loader:

```
 nixpkgs.overlays = [
     (final: prev: {
       wrapQemuBinfmtP =
         name: emulator:
         prev.wrapQemuBinfmtP name (
           pkgs.runCommand "${name}-arg-wrapper"
             {
               nativeBuildInputs = [ final.pkgs.makeWrapper ];
             }
             ''
               makeWrapper ${emulator} $out --run ' 
                 #set -x
                 #MODARGS=(-E "LD_LIBRARY_PATH=/nix/store/razasrvdg7ckplfmvdxv4ia3wbayr94s-bootstrap-tools" /nix/store/razasrvdg7ckplfmvdxv4ia3wbayr94s-bootstrap-tools/lib/ld-linux-x86-64.so.2)
                 MODARGS=() 
                  
                 DASH_DASH_SEEN=0
                 DYNAMIC_LOADER_SET=0
                 function set_dynamic_loader {
                     TOOLSROOT=$1
                     for FILENAME in ''${TOOLSROOT}lib/ld-linux-*; do
                       if [[ "$DYNAMIC_LOADER_SET" == 0 ]]; then
                           MODARGS+=(-E)
                           MODARGS+=("LD_LIBRARY_PATH=$LD_LIBRARY_PATH:''${TOOLSROOT}")
                           MODARGS+=(''${FILENAME})
                           DYNAMIC_LOADER_SET=1
                       fi
                       break
                     done
                 }
                 for ARG in "$@"; do
                   
                   if [[ "$ARG" =~ (/nix/store/.*-bootstrap-tools/)bin/ ]]; then
                     TOOLSROOT=''${BASH_REMATCH[1]}
                     set_dynamic_loader $TOOLSROOT
                   fi
                   if [[ "$ARG" =~ (/nix/store/.*-bootstrap-stage0-binutils-wrapper-/)bin/ ]]; then
                       # Read ld script with only shell builtins to examine the TOOLSROOT directory
                       while IFS= read -r line; do
                         if [[ "$line" =~ (/nix/store/.*-bootstrap-tools/)bin/ld ]]; then
                           TOOLSROOT=''${BASH_REMATCH[1]}
                           set_dynamic_loader $TOOLSROOT
                           break
                         fi
                       done < ''${BASH_REMATCH[1]}bin/ld
                   fi
                  
                   if [[ $DASH_DASH_SEEN == 1 ]]; then
                     MODARGS+=("$ARG")  
                   fi
                   if [[ "$ARG" == "--" ]]; then
                     DASH_DASH_SEEN=1
                   fi
                 done
                 set -- "''${MODARGS[@]}"
             '

             ''
         );
     })
 ];
```

This overlay results in binfmt to execute a binary with qemu-user that may look similar to this:
```
/nix/store/34ph3573s5lz3swl5g1mf32z3ca981wf-qemu-user-9.1.2/bin/qemu-x86_64 /nix/store/razasrvdg7ckplfmvdxv4ia3wbayr94s-bootstrap-tools/lib/ld-linux-x86-64.so.2 /nix/store/razasrvdg7ckplfmvdxv4ia3wbayr94s-bootstrap-tools/bin/stat --printf %y ./configure
```