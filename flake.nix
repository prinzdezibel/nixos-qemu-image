{
  inputs = {
    #nixpkgs.url = "/mnt/home/michael/github/NixOS/nixpkgs";
    nixpkgs.url = "github:prinzdezibel/nixpkgs?ref=21a10700f239d6717f016e7f5aecd9a2be52af08";
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

      forAllSystems =
        function:
        nixpkgs.lib.genAttrs (nixpkgs.lib.attrNames platformConfigMatrix) (
          system: function nixpkgs.legacyPackages.${system}.pkgsCross.${platformConfigMatrix.${system}}
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
                  }
                  // lib.optionalAttrs (config.nixpkgs.system != "x86_64-linux") {
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
            nixpkgs.system = buildSystem;
            
            # This pulls in nixos-containers which depend on Perl.
            boot.enableContainers = false;

            system.stateVersion = lib.version;
          };
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
