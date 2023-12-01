{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        flake-parts.flakeModules.easyOverlay
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux" ];
      flake = {
        nixosModules = {
          macos-ventura = { ... }: {
            imports = [ ./makeDarwinImage/module.nix ];
            nixpkgs.overlays = [ inputs.self.overlays.default ];
          };
        };
      };
      perSystem = { config, pkgs, system, ... }:
        let
          genOverridenDrvList = drv: howMany: builtins.genList (x: drv.overrideAttrs { name = drv.name + "-" + toString x; }) howMany;
          genOverridenDrvLinkFarm = drv: howMany: pkgs.linkFarm (drv.name + "-linkfarm-${toString howMany}") (builtins.genList (x: rec { name = toString x + "-" + drv.name; path = drv.overrideAttrs { inherit name; }; }) howMany);
        in
      {
        _module.args.pkgs = import inputs.nixpkgs {
          overlays = [
            inputs.self.overlays.default
            (self: super: {
              dosbox-x = super.dosbox-x.overrideAttrs {
                src = super.fetchFromGitHub {
                  owner = "joncampbell123";
                  repo = "dosbox-x";
                  rev = "f8e923696c29760aae974e9444229ed210d97cb9";
                  hash = "sha256-3VP0dTAntWPzrGOIxI22/Y6ienq9rYUf7wMlHd6flu4=";
                };
              };
            })
          ];
          inherit system;
        };
        overlayAttrs = config.legacyPackages;
        legacyPackages = {
          makeDarwinImage = pkgs.callPackage ./makeDarwinImage {
            # substitute relative input with absolute input
            qemu_kvm = pkgs.qemu_kvm.overrideAttrs {
              prePatch = ''
                substituteInPlace ui/ui-hmp-cmds.c --replace "qemu_input_queue_rel(NULL, INPUT_AXIS_X, dx);" "qemu_input_queue_abs(NULL, INPUT_AXIS_X, dx, 0, 1920);"
                substituteInPlace ui/ui-hmp-cmds.c --replace "qemu_input_queue_rel(NULL, INPUT_AXIS_Y, dy);" "qemu_input_queue_abs(NULL, INPUT_AXIS_Y, dy, 0, 1080);"
              '';
            };
          };
          makeMsDos622Image = pkgs.callPackage ./makeMsDos622Image {};
          makeWin30Image = pkgs.callPackage ./makeWin30Image {};
          makeWfwg311Image = pkgs.callPackage ./makeWfwg311Image {};
          makeSystem7Image = pkgs.callPackage ./makeSystem7Image {};
        };
        apps = {
          macos-ventura = {
            type = "app";
            program = config.packages.macos-ventura-image.runScript;
          };
          msdos622 = {
            type = "app";
            program = config.packages.msdos622-image.runScript;
          };
          win30 = {
            type = "app";
            program = config.packages.win30-image.runScript;
          };
          wfwg311 = {
            type = "app";
            program = config.packages.wfwg311-image.runScript;
          };
        };
        packages = rec {
          macos-ventura-image = config.legacyPackages.makeDarwinImage {};
          msdos622-image = config.legacyPackages.makeMsDos622Image {};
          win30-image = config.legacyPackages.makeWin30Image {};
          wfwg311-image = config.legacyPackages.makeWfwg311Image {};
          system7-image = config.legacyPackages.makeSystem7Image {};
          macos-repeatability-test = genOverridenDrvLinkFarm macos-ventura-image 10;
          wfwg311-repeatability-test = genOverridenDrvLinkFarm wfwg311-image 1000;
          win30-repeatability-test = genOverridenDrvLinkFarm win30-image 1000;
          msDos622-repeatability-test = genOverridenDrvLinkFarm msdos622-image 1000;
        };
        checks = {
          macos-ventura = pkgs.callPackage ./makeDarwinImage/vm-test.nix { nixosModule = inputs.self.nixosModules.macos-ventura; };
        };
      };
    };
}
