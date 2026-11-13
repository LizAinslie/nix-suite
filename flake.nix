{
  description = "nix-suite: small, individually switchable NixOS / home-manager tools";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
    in
    {
      nixosModules = {
        default = ./modules/nixos;
        crypt-keeper = ./modules/nixos/crypt-keeper.nix;
        gc = ./modules/nixos/gc.nix;
        npm = ./modules/nixos/npm.nix;
        nvd-diff = ./modules/nixos/nvd-diff.nix;
        rebuild-helpers = ./modules/nixos/rebuild-helpers.nix;
        shell = ./modules/nixos/shell.nix;
      };

      homeModules = {
        default = ./modules/home;
        crypt-keeper = ./modules/home/crypt-keeper.nix;
        npm = ./modules/home/npm.nix;
        rebuild-helpers = ./modules/home/rebuild-helpers.nix;
        shell = ./modules/home/shell.nix;
      };
      # Older name, same modules.
      homeManagerModules = self.homeModules;

      lib.mkCryptKeeper = pkgs: import ./lib/crypt-keeper.nix { inherit lib pkgs; };

      # Eval checks: a minimal NixOS system with the default module imported
      # (everything off) must equal one without it, and one with every tool on
      # must evaluate.
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          base = {
            nixpkgs.hostPlatform = system;
            boot.loader.grub.enable = false;
            fileSystems."/" = {
              device = "/dev/null";
              fsType = "ext4";
            };
            networking.hostName = "check";
            system.stateVersion = "26.05";
          };
          eval = modules: (lib.nixosSystem { modules = [ base ] ++ modules; }).config;
          plain = eval [ ];
          off = eval [ self.nixosModules.default ];
          on = eval [
            self.nixosModules.default
            {
              programs.fish.enable = true;
              programs.zsh.enable = true;
              nix-suite = {
                rebuild-helpers.enable = true;
                shell.enable = true;
                npm.enable = true;
                nvd-diff.enable = true;
                gc.enable = true;
                crypt-keeper = {
                  enable = true;
                  drives = [
                    {
                      alias = "dev";
                      uuid = "00000000-0000-0000-0000-000000000000";
                      mountPoint = "/mnt/dev";
                    }
                  ];
                };
              };
            }
          ];
          expectedNrs = "sudo nixos-rebuild switch --flake /etc/nixos#check";
        in
        assert off.system.build.toplevel.drvPath == plain.system.build.toplevel.drvPath;
        assert on.programs.fish.shellAbbrs.nrs == expectedNrs;
        assert on.programs.fish.shellAbbrs ? udb;
        assert on.programs.fish.shellAbbrs.ll == "ls -l";
        assert on.programs.zsh.shellAliases.nrs == expectedNrs;
        assert on.programs.bash.shellAliases.nadd == "git -C /etc/nixos add .";
        assert on.nix-suite.npm.enable;
        assert builtins.match ".*NPM_CONFIG_PREFIX.*" on.environment.extraInit != null;
        assert builtins.match ".*YARN_CACHE_FOLDER.*" on.environment.extraInit != null;
        assert builtins.match ".*PNPM_HOME.*" on.environment.extraInit != null;
        assert builtins.match ".*BUN_INSTALL_CACHE_DIR.*" on.environment.extraInit != null;
        {
          modules-eval = pkgs.writeText "nix-suite-eval" ''
            off: ${builtins.unsafeDiscardStringContext off.system.build.toplevel.drvPath}
            on:  ${builtins.unsafeDiscardStringContext on.system.build.toplevel.drvPath}
          '';
          crypt-keeper-syntax = pkgs.runCommand "crypt-keeper-syntax" { } ''
            ${pkgs.bash}/bin/bash -n ${on.nix-suite.crypt-keeper.package}/bin/crypt-keeper
            touch $out
          '';
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
