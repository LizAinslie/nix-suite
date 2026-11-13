# home-manager variant of shell helpers. Same options as the NixOS module;
# packages go to home.packages, and fish is enabled via HM's programs.fish.
{ config, lib, pkgs, ... }:

let
  cfg = config.nix-suite.shell;

  udbCmd = ''update-desktop-database ~/.local/share/applications /run/current-system/sw/share/applications 2>/dev/null; systemctl --user try-restart vicinae.service 2>/dev/null; true'';

  commands =
    lib.optionalAttrs cfg.ll.enable { ll = "ls -l"; }
    // lib.optionalAttrs cfg.la.enable { la = "ls -la"; }
    // lib.optionalAttrs cfg.udb.enable { udb = udbCmd; }
    // cfg.extraCommands;
in
{
  options.nix-suite.shell = {
    enable = lib.mkEnableOption "shared fish-first shell helpers (ll / la / udb, desktop-file-utils)";

    enableFish = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable programs.fish (needed for abbreviations to expand like nrs).";
    };

    ll.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add `ll` → `ls -l`.";
    };
    la.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add `la` → `ls -la`.";
    };
    udb.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add `udb` → refresh .desktop DBs and restart Vicinae if present.";
    };

    extraCommands = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra name → command entries merged into the abbr/alias table.";
    };

    commands = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = commands;
      description = "The resulting name → command table (read-only).";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [ pkgs.desktop-file-utils ];
      }
      (lib.mkIf cfg.enableFish { programs.fish.enable = true; })
      (lib.mkIf (cfg.enableFish && config.programs.fish.enable) {
        programs.fish.shellAbbrs = commands;
      })
      (lib.mkIf (config.programs.zsh.enable or false) { programs.zsh.shellAliases = commands; })
      (lib.mkIf (config.programs.bash.enable or false) { programs.bash.shellAliases = commands; })
    ]
  );
}
