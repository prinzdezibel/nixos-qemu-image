{
  inputs = {
    #nixpkgs.url = "/mnt/home/michael/github/NixOS/nixpkgs";
    nixpkgs.url = "github:prinzdezibel/nixpkgs?ref=master";
    #nixpkgs.url = "github:NixOS/nixpkgs?ref=master";
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
              let
                bootLoader = builtins.readFile ./modules/bootloader.nix;
                configFile = pkgs.writeText "configuration.nix" ''
                  {pkgs, ...}: {
                      imports = [ 
                        ./modules/base-system.nix
                        ${bootLoader}
                        ./modules/hardware-configuration.nix
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
                    partitionTableType = "hybrid";

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
            ./modules/bootloader.nix
            ./modules/hardware-configuration.nix
            ./modules/cloud-init.nix
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

          # This pulls in nixos-containers which depends on Perl.
          boot.enableContainers = false;

          system.stateVersion = lib.version;
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
