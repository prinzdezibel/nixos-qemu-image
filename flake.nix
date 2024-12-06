{
  inputs = {
    #nixpkgs.url = "/mnt/home/michael/github/NixOS/nixpkgs";
    nixpkgs.url = "github:prinzdezibel/nixpkgs?ref=master";
    #nixpkgs.url = "github:NixOS/nixpkgs?ref=master";

    moduleDir = {
      url = "path:./modules";
      flake = false;
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      moduleDir,
      ...
    }:
    let

      buildSystem = "aarch64-linux"; # Change this if you're building on Intel arch

      platformConfigMatrix = {
        x86_64-linux = "x86_64-unknown-linux-gnu"; # target build configuration for x86_64 builds
        aarch64-linux = "aarch64-unknown-linux-gnu"; # target build configuration for arm builds
      };

      forAllSystems =
        function:
        nixpkgs.lib.genAttrs (nixpkgs.lib.attrNames platformConfigMatrix) (
          system: function nixpkgs.legacyPackages.${system}
        );
    in
    {
      nixosModules.images =
        {
          config,
          lib,
          pkgs,
          modulesPath,
          system,
          ...
        }:
        {
          imports = [
            (
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

                fileSystems."/" = {
                  device = "/dev/disk/by-label/nixos";
                  autoResize = true;
                  fsType = "ext4";
                };

                boot.growPartition = true;
                boot.kernelParams = [ "console=ttyS0" ];
                boot.loader.grub.device =
                  if (nixpkgs.system == "x86_64-linux") then (lib.mkDefault "/dev/vda") else (lib.mkDefault "nodev");

                boot.loader.grub.efiSupport = lib.mkIf (nixpkgs.system != "x86_64-linux") (lib.mkDefault true);
                boot.loader.grub.efiInstallAsRemovable = lib.mkIf (nixpkgs.system != "x86_64-linux") (
                  lib.mkDefault true
                );
                boot.loader.timeout = 5;

                system.build.qcow = import "${toString modulesPath}/../lib/make-disk-image.nix" (
                  {
                    inherit lib config pkgs;
                    inherit (config.virtualisation) diskSize;
                    format = "qcow2";
                    partitionTableType = "hybrid";
                    configFile = pkgs.writeText "configuration.nix" ''
                      {pkgs, ...}: {
                          imports = [ ./modules ];
                      }
                    '';
                    contents = [

                      # Touch /etc/os-release (needed by activation script)
                      {
                        source = pkgs.writeText "os-release" '''';
                        target = "etc/os-release";
                      }
                      {
                        source = ./modules/base-system.nix;
                        #source = "${moduleDir}/base-system.nix";
                        target = "etc/nixos/modules/base-system.nix";
                      }
                      {
                        source = "${moduleDir}/cloud-init.nix";
                        target = "etc/nixos/modules/cloud-init.nix";
                      }
                      {
                        source = "${moduleDir}/default.nix";
                        target = "etc/nixos/modules/default.nix";
                      }
                    ];
                  }
                  // lib.optionalAttrs (config.nixpkgs.system != "x86_64-linux") {
                    touchEFIVars = config.boot.loader.efi.canTouchEfiVariables;
                  }
                );
              }
            )

            #"${moduleDir}/base-system.nix"
            ./modules/base-system.nix
            #./modules/cloud-init.nix
            #"${moduleDir}/cloud-init.nix"
            #"${modulesPath}/profiles/qemu-guest.nix"
            "${modulesPath}/profiles/perlless.nix"
            "${modulesPath}/profiles/minimal.nix"
            #"${modulesPath}/profiles/clone-config.nix"
          ];

          # Supposed way of configuring, but that uses qemu + binfmt?? and is veeerrrrry slow..
          # nixpkgs.hostPlatform = buildSystem;

          # Legacy
          nixpkgs.system = buildSystem;
          nixpkgs.crossSystem = {
            system = system;
            config = platformConfigMatrix.${system};
          };

          environment = {
            # Prevent cross compile error "Option environment.ldso32 currently only works on x86_64"
            # Don't support 32 bit.
            ldso32 = lib.mkIf (system == "x86_64-linux") null;
          };

          # override useDHCP from qemu-guest.nix
          networking.useDHCP = false;

          # Perl is a default package and can't be cross-compiled. Remove it.
          environment.defaultPackages = lib.mkDefault [ ];

          system.stateVersion = lib.version;

          boot.loader = {
            systemd-boot.enable = true;
            efi = {
              canTouchEfiVariables = true;
            };
            grub.enable = false;
          };

          # installer = {
          #   cloneConfigIncludes = [
          #     "./modules"
          #   ];
          #   cloneConfigExtra = ''
          #     system.stateVersion = "${lib.version}";
          #   '';
          # };
        };

      nixosConfigurations = forAllSystems (
        { system, ... }:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit system;
          };
          modules = [ self.nixosModules.images ];
        }
      );
    };
}
