{
  inputs = {
    #nixpkgs.url = "/mnt/home/michael/github/NixOS/nixpkgs";
    nixpkgs.url = "github:prinzdezibel/nixpkgs?ref=d0da7daf0ecc03be5acad2d0340d967530c97ca3";
    #nixpkgs.url = "github:NixOS/nixpkgs?ref=staging";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let

      buildSystem = "aarch64-linux"; # Change this if you're building on Intel arch

      platformConfigMatrix = {
        x86_64-linux = "gnu64";
        aarch64-linux = "aarch64-multiplatform";
      };

      llvmTripleMatrix = {
        x86_64-linux = "x86_64-unknown-linux-gnu";
        aarch64-linux = "aarch64-unknown-linux-gnu";
      };

      forAllSystems =
        function:
        nixpkgs.lib.genAttrs (nixpkgs.lib.attrNames platformConfigMatrix) (
          platformConfigMatrixAttr:
          function {
            system = platformConfigMatrixAttr;
            # nixos =
            #   nixpkgs.legacyPackages.${buildSystem}.pkgsCross.${
            #     platformConfigMatrix.${platformConfigMatrixAttr}
            #   }.nixos;
            nixos = nixpkgs.lib.nixosSystem;
          }
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
          options = {
            emulatedUEFI = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Emulation of an UEFI environment on legacy BIOS systems. Uses Clover bootloader to chainload systemd-boot.
                Does only work for x86_64 architecture.
              '';
            };
          };

          imports = [
            (
              {
                config,
                lib,
                pkgs,
                modulesPath,
                ...
              }:
              let
                configuration = builtins.readFile ./modules/configuration.nix;
                configFile = pkgs.writeText "configuration.nix" ''
                  {pkgs, ...}: {
                      imports = [ 
                        ./modules/base-system.nix
                        ${configuration}
                       ];
                      
                      system.stateVersion = "${lib.version}";
                  }
                '';
              in
              {

                system.build.qcow = import "${toString modulesPath}/../lib/make-disk-image.nix" (
                  {
                    inherit lib config pkgs;
                    inherit (config.virtualisation) diskSize;
                    format = "qcow2";
                    partitionTableType = "efi";
                    bootSize = "2048M";

                    contents = [
                      # Touch /etc/os-release (needed by activation script)
                      {
                        source = pkgs.writeText "os-release" '''';
                        target = "etc/os-release";
                      }
                      {
                        source = configFile;
                        target =
                          if config.system.etc.overlay.enable then
                            ".rw-etc/upper/nixos/configuration.nix"
                          else
                            "etc/nixos/configuration.nix";
                        mode = "0755";
                      }
                      {
                        source = ./modules;
                        target =
                          if config.system.etc.overlay.enable then ".rw-etc/upper/nixos/modules" else "etc/nixos/modules";
                        mode = "0755";
                      }
                    ];

                    touchEFIVars = config.boot.loader.efi.canTouchEfiVariables;
                  }
                );
              }
            )

            ./modules/base-system.nix
            ./modules/configuration.nix
            ./modules/cloud-init.nix
          ];

          config = {
            # Build platform
            nixpkgs.system = buildSystem;

            # Target platform
            nixpkgs.crossSystem = {
              system = system;
              config = llvmTripleMatrix.${system};
            };

            nixpkgs.overlays = [
              (final: prev: {

              })
            ];

            environment = {
              # Prevent cross compile error "Option environment.ldso32 currently only works on x86_64"
              # Don't support 32 bit.
              ldso32 = lib.mkIf (pkgs.system == "x86_64-linux") null;
            };

            # This pulls in nixos-containers which depend on Perl.
            boot.enableContainers = false;

            system.stateVersion = lib.version;
          };
        };

      nixosConfigurations = forAllSystems (
        {
          system,
          nixos,
        }:
        rec {
          nixosConfigurations = nixos {

            # a) nixpkgs.lib.nixosSystem
            modules = [ self.nixosModules.images ];
            specialArgs = {
              inherit system;
            };

            # b) nixpkgs.legacyPackages.x86-64-linux.pkgsCross.gnu64.nixos
            # system = buildSystem;
            # imports = [
            #   {
            #     # Set system as special arguments for all submodules
            #     _module.args = {
            #       inherit system;
            #     };
            #   }
            #   self.nixosModules.images
            # ];
          };
          qcow = nixosConfigurations.config.system.build.qcow;
        }
      );
    };
}
